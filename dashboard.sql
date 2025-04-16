/*Сколько у нас пользователей заходят на сайт?*/
SELECT COUNT(DISTINCT s.visitor_id)
FROM sessions AS s;

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
    medium NOT IN ('organic');
        
/*Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам*/
SELECT
    DATE(s.visit_date) AS visit_date,
    s.source,
    s.medium,
    s.campaign,
    COUNT(DISTINCT s.visitor_id) AS visitors_count
FROM
    sessions AS s
GROUP BY
    1, 2, 3, 4
ORDER BY
    1, 2, 3, 4;
   
/*Сколько лидов к нам приходят?*/
SELECT COUNT(DISTINCT l.visitor_id) AS total_leads
FROM
    leads AS l;
   
   
/*Какая конверсия из клика в лид? А из лида в оплату?*/
  WITH total_clicks AS (
    SELECT COUNT(DISTINCT visitor_id) AS total_clicks
    FROM
        sessions
),

total_leads AS (
    SELECT COUNT(DISTINCT visitor_id) AS total_leads
    FROM
        leads
),

total_purchases AS (
    SELECT COUNT(DISTINCT visitor_id) AS total_purchases
    FROM
        leads
    WHERE
        status_id = 142 OR closing_reason = 'Успешно реализовано'
)

SELECT
    (
        CAST(total_leads AS FLOAT) / total_clicks
    ) AS click_to_lead_conversion_rate,
    (
        CAST(total_purchases AS FLOAT) / total_leads
    ) AS lead_to_purchase_conversion_rate
FROM
    total_clicks, total_leads, total_purchases;

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
    source,
    medium,
    campaign,
    SUM(cost) AS total_cost
FROM ad_costs
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4;


/*Окупаются ли каналы?*/
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
        s.medium <> 'organic'
),

ads AS (
    SELECT
        'VK' AS ads_source,
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM vk_ads
    GROUP BY 1, 2, 3, 4, 5

    UNION ALL

    SELECT
        'Yandex' AS ads_source,
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM ya_ads
    GROUP BY 1, 2, 3, 4, 5
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
    ads.ads_source,
    SUM(lpc.visitors_count) AS visitors_count,
    SUM(lpc.leads_count) AS leads_count,
    SUM(lpc.purchases_count) AS purchases_count,
    SUM(lpc.revenue) AS revenue,
    SUM(ads.daily_spent) AS total_cost,
    CASE
        WHEN
            ROUND(
                (
                    (SUM(lpc.revenue) - SUM(ads.daily_spent))
                    / NULLIF(SUM(ads.daily_spent), 0)
                )
                * 100,
                2
            )
            > 0
            THEN 'Окупается'
        WHEN
            ROUND(
                (
                    (SUM(lpc.revenue) - SUM(ads.daily_spent))
                    / NULLIF(SUM(ads.daily_spent), 0)
                )
                * 100,
                2
            )
            = 0
            THEN 'Нейтрально'
        ELSE 'Не окупается'
    END AS profitability
FROM lpc
LEFT JOIN ads
    ON
        CAST(ads.campaign_date AS DATE) = CAST(lpc.visit_date AS DATE)
        AND lpc.utm_source = ads.utm_source
        AND lpc.utm_medium = ads.utm_medium
        AND lpc.utm_campaign = ads.utm_campaign
WHERE ads.ads_source IS NOT NULL
GROUP BY ads.ads_source;

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
        ROW_NUMBER() OVER (PARTITION BY s.visitor_id ORDER BY s.visit_date DESC) AS rn
    FROM
        sessions s
    LEFT JOIN leads l ON s.visitor_id = l.visitor_id AND s.visit_date <= l.created_at
    WHERE
        s.medium <> 'organic'
)
, ads as 
(SELECT 
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM ya_ads
    GROUP BY 1,2,3,4
    UNION ALL
    SELECT 
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS daily_spent
    FROM vk_ads
    GROUP BY 1,2,3,4)
, lpc as 
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
SELECT lpc.visit_date,
    ads.utm_source,
    ads.utm_medium,
    ads.utm_campaign,
    SUM(lpc.visitors_count) AS visitors_count,
    SUM(ads.daily_spent) AS total_cost,
    SUM(lpc.leads_count) AS leads_count,
    SUM(lpc.purchases_count) AS purchases_count,
    SUM(lpc.revenue) AS revenue
    -- Расчет метрик
    ROUND(SUM(ads.daily_spent) / NULLIF(SUM(lpc.visitors_count), 0), 2) AS cpu,
    ROUND(SUM(ads.daily_spent) / NULLIF(SUM(lpc.leads_count), 0), 2) AS cpl,
    ROUND(SUM(ads.daily_spent) / NULLIF(SUM(lpc.purchases_count), 0), 2) AS cppu,
    ROUND(((SUM(lpc.revenue) - SUM(ads.daily_spent)) / NULLIF(SUM(ads.daily_spent), 0)) * 100, 2) AS roi
FROM lpc
LEFT JOIN ads 
ON CAST(ads.campaign_date AS DATE) = CAST(lpc.visit_date AS DATE)
AND ads.utm_source = lpc.utm_source
AND ads.utm_medium = lpc.utm_medium 
AND ads.utm_campaign = lpc.utm_campaign
WHERE ads.ads_source IS NOT NULL
GROUP BY ads.ads_source;

-- Скрипт для закрытия 90% лидов
WITH lead_times AS (
    SELECT 
        EXTRACT(DAY FROM (l.created_at - s.visit_date)) AS days_to_close
    FROM sessions s
LEFT JOIN leads l
ON s.visitor_id = l.visitor_id
AND l.created_at >= s.visit_date -- Только лиды после визита
    WHERE 
        (l.closing_reason = 'Успешно реализовано' OR l.status_id = 142)
        AND l.created_at IS NOT NULL
)

SELECT 
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY days_to_close) AS p90_days
FROM lead_times;