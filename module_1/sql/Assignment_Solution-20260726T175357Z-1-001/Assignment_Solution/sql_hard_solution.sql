CREATE DATABASE hard_sql;

-- Solution for Question 1

SELECT
    node,
    CASE
        WHEN parent IS NULL THEN 'ROOT'
        WHEN node NOT IN (
            SELECT DISTINCT parent
            FROM hard_sql.tree
            WHERE parent IS NOT NULL
        ) THEN 'LEAF'
        ELSE 'INNER'
    END AS node_type
FROM hard_sql.tree;

=========================================================

-- Solution for Question 2

WITH ranked AS (
    SELECT
        transaction_id,
        biller_id,
        upi_id,
        amount,
        transaction_timestamp,
        LAG(transaction_timestamp) OVER (
            PARTITION BY biller_id, upi_id, amount
            ORDER BY transaction_timestamp
        ) AS prev_ts
    FROM hard_sql.paytm_transactions
)
SELECT
    COUNT(*) AS repeated_payment_count
FROM ranked
WHERE prev_ts IS NOT NULL
  AND TIMESTAMPDIFF(MINUTE, prev_ts, transaction_timestamp) <= 10;

=========================================================

-- Solution for Question 3

SELECT
    t.request_at AS day,
    ROUND(
        CAST(SUM(
            CASE
                WHEN t.status IN ('cancelled_by_traveler', 'cancelled_by_driver')
                THEN 1 ELSE 0
            END
        ) AS DECIMAL(10,2)) / COUNT(*),
        2
    ) AS cancellation_rate
FROM hard_sql.trips t
JOIN hard_sql.users u_traveler
    ON t.traveler_id = u_traveler.user_id
JOIN hard_sql.users u_driver
    ON t.driver_id = u_driver.user_id
WHERE u_traveler.banned = 'No'
  AND u_driver.banned = 'No'
  AND t.request_at BETWEEN '2024-11-01' AND '2024-11-03'
GROUP BY t.request_at
ORDER BY t.request_at;

=========================================================

-- Solution for Question 4

WITH ranked_sales AS (
    SELECT
        o.seller_id,
        i.item_brand,
        ROW_NUMBER() OVER (
            PARTITION BY o.seller_id
            ORDER BY o.order_date
        ) AS rn
    FROM hard_sql.orders o
    JOIN hard_sql.items i
        ON o.item_id = i.item_id
)
SELECT
    u.user_id AS seller_id,
    CASE
        WHEN rs.item_brand = u.favorite_brand THEN 'yes'
        ELSE 'no'
    END AS "2nd_item_fav_brand"
FROM hard_sql.users u
LEFT JOIN ranked_sales rs
    ON u.user_id = rs.seller_id
   AND rs.rn = 2;

=========================================================

-- Solution for Question 5

WITH monthly_counts AS (
    SELECT
        STR_TO_DATE(DATE_FORMAT(session_start, '%Y-%m-01'), '%Y-%m-%d') AS month,
        COUNT(*) AS long_sessions
    FROM hard_sql.data_sessions
    WHERE duration_seconds > 300
    GROUP BY STR_TO_DATE(DATE_FORMAT(session_start, '%Y-%m-01'), '%Y-%m-%d')
),
with_prev AS (
    SELECT
        month,
        long_sessions,
        LAG(long_sessions) OVER (ORDER BY month) AS prev_month_sessions
    FROM monthly_counts
)
SELECT
    month,
    ROUND(
        (long_sessions - prev_month_sessions) * 100.0
        / prev_month_sessions,
        2
    ) AS growth_percent
FROM with_prev
WHERE prev_month_sessions IS NOT NULL
ORDER BY month;

==========================================================

-- Solution for Question 6

WITH price_changes AS (
    SELECT
        symbol,
        price_date,
        price,
        LAG(price, 1) OVER (PARTITION BY symbol ORDER BY price_date) AS prev_price,
        LAG(price, 2) OVER (PARTITION BY symbol ORDER BY price_date) AS prev2_price,
        LAG(price, 3) OVER (PARTITION BY symbol ORDER BY price_date) AS prev3_price,
        LAG(price_date, 1) OVER (PARTITION BY symbol ORDER BY price_date) AS prev_date,
        LAG(price_date, 2) OVER (PARTITION BY symbol ORDER BY price_date) AS prev2_date,
        LAG(price_date, 3) OVER (PARTITION BY symbol ORDER BY price_date) AS prev3_date
    FROM hard_sql.stock_prices
),
decline_streaks AS (
    SELECT
        symbol,
        price_date AS recovery_date,
        price AS price_on_recovery,
        prev_price,
        prev2_price,
        prev3_price,
        prev_date,
        prev2_date,
        prev3_date,
        CASE
            WHEN prev_price < prev2_price 
             AND prev2_price < prev3_price
             AND price > prev_price
             AND prev_date = DATE_SUB(price_date, INTERVAL 1 DAY)
             AND prev2_date = DATE_SUB(price_date, INTERVAL 2 DAY)
             AND prev3_date = DATE_SUB(price_date, INTERVAL 3 DAY)
            THEN 1
            ELSE 0
        END AS is_recovery_after_3_declines
    FROM price_changes
    WHERE prev_price IS NOT NULL
      AND prev2_price IS NOT NULL
      AND prev3_price IS NOT NULL
)
SELECT
    symbol,
    recovery_date,
    price_on_recovery,
    ROUND((prev_price + prev2_price + prev3_price) / 3.0, 2) AS previous_3_days_avg_price
FROM decline_streaks
WHERE is_recovery_after_3_declines = 1
ORDER BY symbol, recovery_date;

=================================================================

-- Solution for Question 7

WITH patient_medication_doctors AS (
    SELECT
        p.patient_id,
        p.patient_name,
        pr.medication_name,
        COUNT(DISTINCT pr.doctor_id) AS doctor_count,
        GROUP_CONCAT(DISTINCT d.doctor_name ORDER BY d.doctor_name SEPARATOR ', ') AS doctor_names
    FROM hard_sql.prescriptions pr
    JOIN hard_sql.patients p ON pr.patient_id = p.patient_id
    JOIN hard_sql.doctors d ON pr.doctor_id = d.doctor_id
    GROUP BY p.patient_id, p.patient_name, pr.medication_name
    HAVING COUNT(DISTINCT pr.doctor_id) >= 2
)
SELECT
    patient_id,
    patient_name,
    medication_name,
    doctor_count,
    doctor_names
FROM patient_medication_doctors
ORDER BY patient_id, medication_name;


=================================================================

-- Solution for Question 8

with orders_purchase_agg as (
      select 
          c.customer_id,
          c.customer_name,
          o.order_date,
          row_number() over(partition by c.customer_id, c.customer_name order by o.order_date) as purchase_rnk,
          count(order_id) over(partition by c.customer_id, c.customer_name) as total_orders,
          sum(amount) over(partition by c.customer_id, c.customer_name) as total_spent,
          round( avg(amount) over(partition by c.customer_id, c.customer_name) , 2) as avg_order_value
      from hard_sql.ecom_orders o
      join hard_sql.ecom_customers c on o.customer_id = c.customer_id
)

select 
     customer_id,
     customer_name,
     min(order_date) as first_purchase_date,
     max(order_date) as second_purchase_date,
     DATEDIFF(max(order_date), min(order_date)) as days_between_purchases,
     total_orders,
     total_spent,
     avg_order_value
from orders_purchase_agg
where purchase_rnk <= 2 and total_orders > 1
group by customer_id, customer_name, total_orders, total_spent, avg_order_value;


=================================================================

-- Solution for Question 9

with monthly_purchases as (
   select 
      o.customer_id,
      c.customer_name,
      o.product_id,
      p.product_name,
      o.order_date,
      STR_TO_DATE(DATE_FORMAT(o.order_date, '%Y-%m-01'), '%Y-%m-%d') as purchase_month
   from hard_sql.gd_orders o
   join hard_sql.customers c on o.customer_id = c.customer_id
   join hard_sql.products p on p.product_id = o.product_id
)
   
select 
   mp1.customer_id,
   mp1.customer_name,
   mp1.product_id,
   mp1.product_name,
   DATE_FORMAT(mp2.purchase_month , '%Y-%m') as first_month,
   DATE_FORMAT(mp1.purchase_month , '%Y-%m') as second_month
from monthly_purchases mp1
join monthly_purchases mp2 
on mp1.customer_id = mp2.customer_id and mp1.product_id = mp2.product_id 
   and mp1.purchase_month = DATE_ADD(mp2.purchase_month, INTERVAL 1 MONTH);
