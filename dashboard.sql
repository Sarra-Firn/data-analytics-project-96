/*Сколько у нас пользователей заходят на сайт?*/
SELECT COUNT(DISTINCT visitor_id)
FROM sessions;

/*Какие каналы их приводят на сайт*/
SELECT
    visitor_id,
    visit_date,
    source AS utm_source,
    medium AS utm_medium,
    campaign AS utm_campaign
FROM sessions
WHERE medium != 'organic';

/*Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам*/
SELECT
    source,
    medium,
    campaign,
    DATE(visit_date) AS visit_date,
    COUNT(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY
    DATE(visit_date),
    source,
    medium,
    campaign;

/*Сколько лидов к нам приходят?*/
SELECT COUNT(DISTINCT l.visitor_id) AS total_leads
FROM leads AS l;

/*Сколько мы тратим по разным каналам в динамике?*/
SELECT
    campaign_date,
    utm_source AS source,
    utm_medium AS medium,
    utm_campaign AS campaign,
    SUM(daily_spent) AS daily_spent
FROM vk_ads
GROUP BY
    campaign_date,
    utm_source,
    utm_medium,
    utm_campaign
UNION ALL
SELECT
    campaign_date,
    utm_source AS source,
    utm_medium AS medium,
    utm_campaign AS campaign,
    SUM(daily_spent) AS daily_spent
FROM ya_ads
GROUP BY
    campaign_date,
    utm_source,
    utm_medium,
    utm_campaign;

/*Расчёт основных метрик*/
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
        ROW_NUMBER() OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC)
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
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM ya_ads
    GROUP BY
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
    UNION ALL
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM vk_ads
    GROUP BY
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign
),

lpc AS (
    SELECT
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        CAST(visit_date AS DATE) AS visit_date,
        COUNT(lpc.visitor_id) AS visitors_count,
        COUNT(lpc.lead_id) AS leads_count,
        COUNT(
            CASE WHEN lpc.status_id = 142 THEN 1 END
        ) AS purchases_count,
        SUM(lpc.amount) AS revenue
    FROM
        last_paid_click AS lpc
    WHERE
        lpc.rn = 1
    GROUP BY
        CAST(visit_date AS DATE),
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign
)

SELECT
    ads.utm_source,
    ROUND(SUM(ads.daily_spent) / NULLIF(SUM(lpc.visitors_count), 0), 2) AS cpu,
    ROUND(SUM(ads.daily_spent) / NULLIF(SUM(lpc.leads_count), 0), 2) AS cpl,
    ROUND(
        SUM(ads.daily_spent) / NULLIF(SUM(lpc.purchases_count), 0), 2
    ) AS cppu,
    ROUND(
        (
            (SUM(lpc.revenue) - SUM(ads.daily_spent))
            / NULLIF(SUM(ads.daily_spent), 0)
        )
        * 100,
        2
    ) AS roi
FROM lpc
LEFT JOIN ads
    ON
        CAST(ads.campaign_date AS DATE) = CAST(lpc.visit_date AS DATE)
        AND lpc.utm_source = ads.utm_source
        AND lpc.utm_medium = ads.utm_medium
        AND lpc.utm_campaign = ads.utm_campaign
WHERE ads.utm_source IS NOT NULL
GROUP BY ads.utm_source;

-- Скрипт для закрытия 90% лидов
SELECT
    PERCENTILE_CONT(0.9) WITHIN GROUP (
        ORDER BY l.created_at - s.visit_date
    ) AS prc
FROM sessions AS s
LEFT JOIN leads AS l
	ON s.visitor_id = l.visitor_id
	AND s.visit_date <= l.created_at; -- Только лиды после визита