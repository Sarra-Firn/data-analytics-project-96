WITH paid_sessions AS (
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
),
last_paid_click AS (
    SELECT
        ps.visitor_id,
        ps.visit_date,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (PARTITION BY ps.visitor_id ORDER BY ps.visit_date DESC) AS rn
    FROM
        paid_sessions ps
    LEFT JOIN leads l ON ps.visitor_id = l.visitor_id AND ps.visit_date <= l.created_at
)
SELECT
    visitor_id,
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
FROM
    last_paid_click
WHERE
    rn = 1
ORDER BY
    COALESCE(amount, 0) DESC,
    visit_date ASC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC
    limit 10;