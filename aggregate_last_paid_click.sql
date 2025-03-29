WITH sessions_leads AS (
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
),
ads_cost AS (
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
)
SELECT
    sl.visit_date,
    sl.source AS utm_source,
    sl.medium AS utm_medium,
    sl.campaign AS utm_campaign,
    COUNT(DISTINCT sl.visitor_id) AS visitors_count,  
    COALESCE(SUM(ac.daily_spent), 0) AS total_cost,
    SUM(CASE WHEN sl.lead_id IS NOT NULL THEN 1 ELSE 0 END) AS leads_count,
    SUM(CASE WHEN sl.status_id = 142 OR sl.closing_reason = 'Успешно реализовано' THEN 1 ELSE 0 END) AS purchases_count,
    SUM(sl.amount) AS revenue
FROM sessions_leads sl
LEFT JOIN ads_cost ac 
    ON sl.source = ac.utm_source
    AND sl.medium = ac.utm_medium
    AND sl.campaign = ac.utm_campaign
GROUP BY 
    sl.visit_date, 
    sl.source, 
    sl.medium, 
    sl.campaign
ORDER BY 
    revenue DESC NULLS LAST,
    visit_date,
    COUNT(DISTINCT sl.visitor_id) DESC,
    sl.source,
    sl.medium,
    sl.campaign
LIMIT 15;
