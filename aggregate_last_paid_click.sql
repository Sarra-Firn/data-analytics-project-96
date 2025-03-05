WITH 
-- Подзапрос для объединения затрат на рекламу
ad_costs AS (
    SELECT 
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        SUM(daily_spent) AS daily_spent
    FROM (
        SELECT 
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            daily_spent
        FROM 
            ya_ads
        UNION ALL
        SELECT 
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            daily_spent
        FROM 
            vk_ads
    ) AS combined_ads
    GROUP BY 
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content
),
-- Подзапрос для расчета количества лидов и успешных покупок
leads_purchases AS (
    SELECT 
        s.visitor_id, 
        s.visit_date, 
        s.source, 
        s.medium, 
        s.campaign,
        CASE 
            WHEN l.lead_id IS NOT NULL THEN 1 
            ELSE 0 
        END AS is_lead,
        CASE 
            WHEN l.status_id = 142 OR l.closing_reason = 'Успешно реализовано' THEN 1 
            ELSE 0 
        END AS is_purchase,
        COALESCE(l.amount, 0) AS purchase_amount
    FROM 
        sessions s
    LEFT JOIN 
        leads l ON s.visitor_id = l.visitor_id AND s.visit_date = l.created_at
),
-- Подзапрос для агрегации данных
aggregated_data AS (
    SELECT 
        lp.visit_date,
        lp.source AS utm_source,
        lp.medium AS utm_medium,
        lp.campaign AS utm_campaign,
        COUNT(lp.visitor_id) AS visitors_count,
        COALESCE(SUM(ac.daily_spent), 0) AS total_cost,
        SUM(lp.is_lead) AS leads_count,
        SUM(lp.is_purchase) AS purchases_count,
        SUM(lp.purchase_amount) AS revenue
    FROM 
        leads_purchases lp
    LEFT JOIN 
        ad_costs ac ON lp.source = ac.utm_source AND lp.medium = ac.utm_medium AND lp.campaign = ac.utm_campaign
    GROUP BY 
        lp.visit_date, 
        lp.source, 
        lp.medium, 
        lp.campaign
)
-- Основной запрос для витрины данных
SELECT 
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    visitors_count,
    total_cost,
    leads_count,
    purchases_count,
    revenue
FROM 
    aggregated_data
ORDER BY 
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC
LIMIT 15;