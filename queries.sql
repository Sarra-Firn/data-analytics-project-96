/*Сколько у нас пользователей заходят на сайт?*/
SELECT s.visitor_id
FROM sessions s;

/*Какие каналы их приводят на сайт*/
SELECT
        visitor_id,
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign
    FROM
        sessions
    WHERE
        medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
        
/*Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам*/
SELECT
    DATE(s.visit_date) AS visit_date,  -- День
    DATE_TRUNC('week', s.visit_date) AS visit_week,  -- Неделя
    DATE_TRUNC('month', s.visit_date) AS visit_month,  -- Месяц
    s.source,  -- Источник
    s.medium,  -- Тип рекламной кампании
    s.campaign,  -- Название рекламной кампании
    COUNT(DISTINCT s.visitor_id) AS visitors_count  -- Количество уникальных посетителей
FROM
    sessions s
GROUP BY
    1, 2, 3, 4, 5, 6
ORDER BY
    1, 4, 5, 6;
/*Сколько лидов к нам приходят?*/
SELECT
    COUNT(DISTINCT l.visitor_id) AS total_leads
FROM
    leads l;
   
   
/*Какая конверсия из клика в лид? А из лида в оплату?*/
        SELECT
    COUNT(DISTINCT l.visitor_id) AS total_leads
FROM
    leads l;
    
   WITH total_clicks AS (
    SELECT
        COUNT(DISTINCT visitor_id) AS total_clicks
    FROM
        sessions
),
total_leads AS (
    SELECT
        COUNT(DISTINCT visitor_id) AS total_leads
    FROM
        leads
)
SELECT
    (CAST(total_leads AS FLOAT) / total_clicks) AS click_to_lead_conversion_rate
FROM
    total_clicks, total_leads;
    
/*Сколько мы тратим по разным каналам в динамике?*/

   WITH ad_costs AS (
    -- Объединяем данные из vk_ads
    SELECT
        campaign_date AS date,
        utm_source AS source,
        utm_medium AS medium,
        utm_campaign AS campaign,
        SUM(daily_spent) AS cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4

    UNION ALL

    -- Объединяем данные из ya_ads
    SELECT
        campaign_date AS date,
        utm_source AS source,
        utm_medium AS medium,
        utm_campaign AS campaign,
        SUM(daily_spent) AS cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
)

-- Агрегируем данные по дням/неделям/месяцам и каналам
SELECT
    DATE(date) AS daily,
    DATE_TRUNC('week', date) AS weekly,
    DATE_TRUNC('month', date) AS monthly,
    source,
    medium,
    campaign,
    SUM(cost) AS total_cost
FROM ad_costs
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY 1, 4, 5, 6;

/*Окупаются ли каналы?*/
WITH 
ad_costs AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    WHERE utm_source IS NOT NULL
    GROUP BY utm_source, utm_medium, utm_campaign
    UNION ALL
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    WHERE utm_source IS NOT NULL
    GROUP BY utm_source, utm_medium, utm_campaign
),
revenue_data AS (
    SELECT
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        SUM(l.amount) AS total_revenue,
        COUNT(DISTINCT l.lead_id) AS customers_count
    FROM sessions s
    JOIN leads l 
        ON s.visitor_id = l.visitor_id
    WHERE 
        l.closing_reason = 'Успешно реализовано'
        AND l.status_id = 1 -- Используйте числовой идентификатор статуса!
    GROUP BY s.source, s.medium, s.campaign
)
SELECT
    COALESCE(a.utm_source, r.utm_source) AS source,
    COALESCE(a.utm_medium, r.utm_medium) AS medium,
    COALESCE(a.utm_campaign, r.utm_campaign) AS campaign,
    COALESCE(a.total_cost, 0) AS total_cost,
    COALESCE(r.total_revenue, 0) AS total_revenue,
    COALESCE(r.customers_count, 0) AS customers,
    CASE 
        WHEN a.total_cost > 0 THEN (r.total_revenue - a.total_cost) / a.total_cost * 100 
        ELSE NULL 
    END AS ROI_percent,
    COALESCE(a.total_cost / NULLIF(r.customers_count, 0), 0) AS CAC,
    COALESCE(r.total_revenue / NULLIF(r.customers_count, 0), 0) AS avg_revenue_per_customer
FROM ad_costs a
FULL OUTER JOIN revenue_data r 
    ON a.utm_source = r.utm_source 
    AND a.utm_medium = r.utm_medium 
    AND a.utm_campaign = r.utm_campaign
ORDER BY ROI_percent DESC NULLS LAST;

/*Расчёт основных метрик*/
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
        leads l ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
),
-- Подзапрос для агрегации данных
aggregated_data AS (
    SELECT 
        lp.visit_date,
        lp.source AS utm_source,
        lp.medium AS utm_medium,
        lp.campaign AS utm_campaign,
        COUNT(DISTINCT lp.visitor_id) AS visitors_count,
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
    utm_source,
    SUM(visitors_count) AS visitors_count,
    SUM(total_cost) AS total_cost,
    SUM(leads_count) AS leads_count,
    SUM(purchases_count) AS purchases_count,
    SUM(revenue) AS revenue,
    ROUND(SUM(total_cost) / NULLIF(SUM(visitors_count), 0), 2) AS cpu,
    ROUND(SUM(total_cost) / NULLIF(SUM(leads_count), 0), 2) AS cpl,
    ROUND(SUM(total_cost) / NULLIF(SUM(purchases_count), 0), 2) AS cppu,
    ROUND((SUM(revenue) - SUM(total_cost)) / NULLIF(SUM(total_cost), 0) * 100, 2) AS roi
FROM aggregated_data
WHERE utm_source IN ('vk', 'yandex')
GROUP BY utm_source
ORDER BY utm_source;