WITH last_paid_click AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC) AS rn
    FROM
        sessions s
    LEFT JOIN leads l ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
    WHERE
        s.medium <> 'organic'
),
ads AS 
(
    SELECT 
        'VK' AS ads_source,
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM vk_ads
    GROUP BY 1,2,3,4,5

    UNION ALL

    SELECT 
        'Yandex' AS ads_source,
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM ya_ads
    GROUP BY 1,2,3,4,5
),
lpc AS 
(
    SELECT
        CAST(visit_date AS DATE) AS visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        COUNT(visitor_id) AS visitors_count,
        COUNT(lead_id) AS leads_count,
        COUNT(CASE WHEN status_id = 142 THEN 1 ELSE NULL END) AS purchases_count,
        SUM(amount) AS revenue
    FROM
        last_paid_click lpc
    WHERE
        rn = 1
    GROUP BY 
        CAST(visit_date AS DATE),
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign
)
SELECT 
    ads.ads_source,
    SUM(lpc.visitors_count) AS visitors_count,
    SUM(lpc.leads_count) AS leads_count,
    SUM(lpc.purchases_count) AS purchases_count,
    SUM(lpc.revenue) AS revenue,
    SUM(ads.daily_spent) AS total_cost
FROM lpc
LEFT JOIN ads 
ON CAST(ads.campaign_date AS DATE) = CAST(lpc.visit_date AS DATE)
AND ads.utm_source = lpc.utm_source
AND ads.utm_medium = lpc.utm_medium 
AND ads.utm_campaign = lpc.utm_campaign
WHERE ads.ads_source IS NOT NULL
GROUP BY ads.ads_source, lpc.visit_date
order by revenue desc NULLS LAST,
visit_date,
visitors_count,
ads.ads_source
limit 15;