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
        ROW_NUMBER() OVER (
            PARTITION BY s.visitor_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM sessions AS s
    LEFT JOIN leads AS l
        ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
    WHERE s.medium != 'organic'
),

ads AS (
    SELECT
        CAST(campaign_date AS date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY campaign_date, utm_source, utm_medium, utm_campaign

    UNION ALL

    SELECT
        CAST(campaign_date AS date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY campaign_date, utm_source, utm_medium, utm_campaign
),

lpc AS (
    SELECT
        lpc_data.utm_source,
        lpc_data.utm_medium,
        lpc_data.utm_campaign,
        CAST(lpc_data.visit_date AS date) AS visit_date,
        COUNT(lpc_data.visitor_id) AS visitors_count,
        COUNT(lpc_data.lead_id) AS leads_count,
        SUM(CASE WHEN lpc_data.status_id = 142 THEN 1 ELSE 0 END) AS purchases_count,
        SUM(lpc_data.amount) AS revenue
    FROM last_paid_click AS lpc_data
    WHERE lpc_data.rn = 1
    GROUP BY
        visit_date,
        lpc_data.utm_source,
        lpc_data.utm_medium,
        lpc_data.utm_campaign
)

SELECT
    l.visit_date,
    l.visitors_count,
    l.utm_source,
    l.utm_medium,
    l.utm_campaign,
    ads.total_cost,
    l.leads_count,
    l.purchases_count,
    l.revenue
FROM lpc AS l
LEFT JOIN ads
    ON ads.campaign_date = l.visit_date
    AND l.utm_source = ads.utm_source
    AND l.utm_medium = ads.utm_medium
    AND l.utm_campaign = ads.utm_campaign
ORDER BY
    l.revenue DESC NULLS LAST,
    l.visit_date ASC,
    l.visitors_count DESC,
    l.utm_source ASC,
    l.utm_medium ASC,
    l.utm_campaign ASC
LIMIT 15;
