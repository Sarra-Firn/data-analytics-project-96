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
        ROW_NUMBER()
        OVER (
            PARTITION BY s.visitor_id
            ORDER BY s.visit_date DESC
        )
        AS rn
    FROM
        sessions AS s
    LEFT JOIN
        leads AS l
        ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
    WHERE
        s.medium != 'organic'
),

ads AS (
    SELECT
        CAST(campaign_date AS date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
    UNION ALL
    SELECT
        CAST(campaign_date AS date) AS campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4
),

lpc AS (
    SELECT
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        CAST(s.visit_date AS date) AS visit_date,
        COUNT(lpc.visitor_id) AS visitors_count,
        COUNT(lpc.lead_id) AS leads_count,
        SUM(CASE WHEN lpc.status_id = 142 THEN 1 ELSE 0 END) AS purchases_count,
        SUM(lpc.amount) AS revenue
    FROM
        last_paid_click AS lpc
    WHERE
        lpc.rn = 1
    GROUP BY
        CAST(s.visit_date AS date),
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign
)

SELECT
    lpc.visit_date,
    lpc.visitors_count,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    ads.total_cost,
    lpc.leads_count,
    lpc.purchases_count,
    lpc.revenue
FROM lpc
LEFT JOIN ads
    ON
        CAST(ads.campaign_date AS date) = lpc.visit_date
        AND lpc.utm_source = ads.utm_source
        AND lpc.utm_medium = ads.utm_medium
        AND lpc.utm_campaign = ads.utm_campaign
--GROUP BY ads.utm_source, ads.utm_medium, ads.utm_campaign, lpc.visit_date
ORDER BY
    lpc.revenue DESC NULLS LAST,
    lpc.visit_date ASC,
    lpc.visitors_count DESC,
    lpc.utm_source ASC,
    lpc.utm_medium ASC,
    lpc.utm_campaign ASC
LIMIT 15;
