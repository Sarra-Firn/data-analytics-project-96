SELECT
    lp.visit_date,
    lp.source AS utm_source,
    lp.medium AS utm_medium,
    lp.campaign AS utm_campaign,
    COUNT(DISTINCT lp.visitor_id) AS visitors_count,  
    COALESCE(SUM(ac.daily_spent), 0) AS total_cost,
    SUM(CASE WHEN lp.lead_id IS NOT NULL THEN 1 ELSE 0 END) AS leads_count,
    SUM(CASE WHEN lp.status_id = 142 OR lp.closing_reason = 'Успешно реализовано' THEN 1 ELSE 0 END) AS purchases_count,
    SUM(lp.amount) AS revenue
FROM (
    SELECT 
        s.visitor_id,
        s.visit_date,
        s.source,
        s.medium,
        s.campaign,
        l.lead_id,
        l.status_id,
        l.closing_reason,
        l.amount
    FROM sessions s
    LEFT JOIN leads l 
        ON s.visitor_id = l.visitor_id
        AND s.visit_date <= l.created_at
) AS lp
LEFT JOIN (
    SELECT 
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM ya_ads
    GROUP BY utm_source, utm_medium, utm_campaign

    UNION ALL

    SELECT 
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM vk_ads
    GROUP BY utm_source, utm_medium, utm_campaign
) AS ac  -- Добавлено AS ac
ON lp.source = ac.utm_source
AND lp.medium = ac.utm_medium
AND lp.campaign = ac.utm_campaign
GROUP BY 
    lp.visit_date, 
    lp.source, 
    lp.medium, 
    lp.campaign
ORDER BY 
    revenue DESC NULLS LAST,
    visit_date,
    COUNT(DISTINCT lp.visitor_id) DESC,
    lp.source,
    lp.medium,
    lp.campaign
LIMIT 15;
