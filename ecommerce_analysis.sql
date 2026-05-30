-- E-Commerce SQL Analysis
-- Dataset: Brazilian Olist E-Commerce Dataset
-- Goal: Analyze sales performance, customer behavior, delivery efficiency, and regional revenue trends.
-- Tools: PostgreSQL, DBeaver, Tableau

-- 1. Order status distribution
-- Business question:
-- What is the distribution of order statuses?
-- Which order status appears most frequently?
SELECT 
    order_status,
    COUNT(*) AS total_orders
FROM public.olist_orders_dataset
GROUP BY order_status
ORDER BY total_orders DESC;


-- 2. Monthly order trends
-- Business question:
-- How did the number of orders change over time?
-- Which months had the highest order volume?
SELECT 
    DATE_TRUNC('month', order_purchase_timestamp::timestamp) AS month,
    COUNT(*) AS total_orders
FROM public.olist_orders_dataset
GROUP BY month
ORDER BY month;


-- 3. Average payment by order status
-- Business question:
-- How does average payment differ by order status?
-- Which order statuses have the highest average payment value?
SELECT
    o.order_status,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(p.payment_value::numeric), 2) AS avg_payment
FROM public.olist_orders_dataset o
JOIN public.olist_order_payments_dataset p
    ON o.order_id = p.order_id
GROUP BY o.order_status
ORDER BY avg_payment DESC;


-- 4. Top customers by total spending
-- Business question:
-- Which customers generated the highest revenue?
-- Who are the top spending customers?
SELECT
    c.customer_id,
    ROUND(SUM(p.payment_value::numeric), 2) AS total_spent,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM public.olist_customers_dataset c
JOIN public.olist_orders_dataset o
    ON c.customer_id = o.customer_id
JOIN public.olist_order_payments_dataset p
    ON o.order_id = p.order_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 10;


-- 5. Monthly revenue analysis using CTE
-- Business question:
-- How did monthly revenue change over time?
-- Which months generated the highest revenue?
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp::timestamp) AS month,
        ROUND(SUM(p.payment_value::numeric), 2) AS revenue
    FROM public.olist_orders_dataset o
    JOIN public.olist_order_payments_dataset p
        ON o.order_id = p.order_id
    GROUP BY month
)

SELECT *
FROM monthly_revenue
ORDER BY revenue DESC;


-- 6. Revenue ranking by month using window function
-- Business question:
-- Which months had the highest revenue?
-- How can we rank months by revenue performance?
WITH monthly_revenue AS (

    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp::timestamp) AS month,
        ROUND(SUM(p.payment_value::numeric), 2) AS revenue
    FROM public.olist_orders_dataset o
    JOIN public.olist_order_payments_dataset p
        ON o.order_id = p.order_id
    GROUP BY month
)

SELECT
    month,
    revenue,
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM monthly_revenue;


-- 7. Revenue by customer state
-- Business question:
-- Which states generated the most revenue?
-- How does revenue vary across customer locations?
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value::numeric), 2) AS total_revenue,
    ROUND(AVG(p.payment_value::numeric), 2) AS avg_order_value
FROM public.olist_customers_dataset c
JOIN public.olist_orders_dataset o
    ON c.customer_id = o.customer_id
JOIN public.olist_order_payments_dataset p
    ON o.order_id = p.order_id
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- 8. Average delivery time
-- Business question:
-- What is the average delivery time in days?
-- How long does delivery typically take?
SELECT
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date::timestamp
                - order_purchase_timestamp::timestamp
            )) / 86400
        )::numeric,
        2
    ) AS avg_delivery_days
FROM public.olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date <> ''
  AND order_purchase_timestamp IS NOT NULL
  AND order_purchase_timestamp <> '';


-- 9. Late deliveries analysis
-- Business question:
-- What percentage of orders were delivered late?
-- How often were deliveries delayed?
SELECT
    COUNT(*) AS total_orders,
    
    COUNT(
        CASE
            WHEN order_delivered_customer_date::timestamp
                 >
                 order_estimated_delivery_date::timestamp
            THEN 1
        END
    ) AS late_deliveries,

    ROUND(
        COUNT(
            CASE
                WHEN order_delivered_customer_date::timestamp
                     >
                     order_estimated_delivery_date::timestamp
                THEN 1
            END
        )::numeric
        /
        COUNT(*) * 100,
        2
    ) AS late_delivery_percentage

FROM public.olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_delivered_customer_date <> ''
  AND order_estimated_delivery_date <> '';


-- 10. Revenue contribution by state
-- Business question:
-- What percentage of total revenue comes from each state?

WITH state_revenue AS (
    SELECT
        c.customer_state,
        ROUND(SUM(p.payment_value::numeric), 2) AS total_revenue
    FROM public.olist_customers_dataset c
    JOIN public.olist_orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN public.olist_order_payments_dataset p
        ON o.order_id = p.order_id
    GROUP BY c.customer_state
)

SELECT
    customer_state,
    total_revenue,
    ROUND(total_revenue / SUM(total_revenue) OVER () * 100, 2) AS revenue_percentage
FROM state_revenue
ORDER BY total_revenue DESC;


-- 11. Repeat customer analysis
-- Business question:
-- How many customers placed more than one order?

WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(order_id) AS total_orders
    FROM public.olist_orders_dataset
    GROUP BY customer_id
)

SELECT
    COUNT(*) AS total_customers,
    COUNT(CASE WHEN total_orders > 1 THEN 1 END) AS repeat_customers,
    ROUND(COUNT(CASE WHEN total_orders > 1 THEN 1 END)::numeric / COUNT(*) * 100, 2) AS repeat_customer_percentage
FROM customer_orders;


-- 12. Delivery performance by state
-- Business question:
-- Which states have the highest late delivery rate?

SELECT
    c.customer_state,
    COUNT(*) AS total_orders,
    COUNT(
        CASE
            WHEN o.order_delivered_customer_date::timestamp > o.order_estimated_delivery_date::timestamp
            THEN 1
        END
    ) AS late_deliveries,
    ROUND(
        COUNT(
            CASE
                WHEN o.order_delivered_customer_date::timestamp > o.order_estimated_delivery_date::timestamp
                THEN 1
            END)::numeric / COUNT(*) * 100, 2) AS late_delivery_rate
FROM public.olist_orders_dataset o
JOIN public.olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND o.order_delivered_customer_date <> ''
  AND o.order_estimated_delivery_date <> ''
GROUP BY c.customer_state
ORDER BY late_delivery_rate DESC;
