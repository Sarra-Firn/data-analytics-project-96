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
        medium not IN ('organic')
        
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
WITH combined_ads AS (
    SELECT 
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        campaign_date,
        SUM(daily_spent) AS daily_spent -- Агрегируем расходы на уровне дня
    FROM (
        SELECT 
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date,
            daily_spent
        FROM vk_ads
        UNION ALL
        SELECT 
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            campaign_date,
            daily_spent
        FROM ya_ads
    ) AS all_ads
    GROUP BY 1,2,3,4,5
),

session_leads AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source,
        s.medium,
        s.campaign,
        s.content,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM sessions s
    LEFT JOIN leads l 
        ON s.visitor_id = l.visitor_id
        AND l.created_at >= s.visit_date -- Только лиды после визита
),

metrics AS (
    SELECT
        s.source as utm_source,
        CAST(s.visit_date AS DATE) AS visit_date,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,
        SUM(DISTINCT a.daily_spent) AS total_cost,
        COUNT(DISTINCT s.lead_id) AS leads_count,
        COUNT(DISTINCT CASE 
            WHEN s.closing_reason = 'Успешно реализовано' OR s.status_id = 142 
            THEN s.lead_id 
        END) AS purchases_count,
        SUM(CASE 
            WHEN s.closing_reason = 'Успешно реализовано' OR s.status_id = 142 
            THEN s.amount 
        END) AS revenue
    FROM session_leads s
    LEFT JOIN combined_ads a 
        ON s.source = a.utm_source
        AND s.medium = a.utm_medium
        AND s.campaign = a.utm_campaign
        AND s.content = a.utm_content
        AND CAST(s.visit_date AS DATE) = a.campaign_date
    GROUP BY 1,2
)

SELECT
    utm_source,
    SUM(visitors_count) AS total_visitors,
    SUM(total_cost) AS total_cost,
    SUM(leads_count) AS total_leads,
    SUM(purchases_count) AS total_purchases,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(total_cost) / NULLIF(SUM(visitors_count), 0), 2) AS cpu,
    ROUND(SUM(total_cost) / NULLIF(SUM(leads_count), 0), 2) AS cpl,
    ROUND(SUM(total_cost) / NULLIF(SUM(purchases_count), 0), 2) AS cppu,
    ROUND((SUM(revenue) - SUM(total_cost)) / NULLIF(SUM(total_cost), 0) * 100, 2) AS roi
FROM metrics
where utm_source in ('vk', 'yandex')
GROUP BY utm_source
ORDER BY roi DESC;
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

