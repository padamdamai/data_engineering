CREATE DATABASE easy_sql;

-- Solution for Question 1

SELECT
    employee_name,
    MAX(sales_amount) - MIN(sales_amount) AS sales_variation
FROM easy_sql.employee_sales
GROUP BY employee_name
ORDER BY sales_variation DESC;

=========================================================

-- Solution for Question 2

SELECT
    customer_id,
    COUNT(*) AS purchase_count
FROM easy_sql.purchases
WHERE purchase_date BETWEEN '2025-01-01' AND '2025-01-31'
GROUP BY customer_id
ORDER BY purchase_count DESC
LIMIT 2;

=========================================================

-- Solution for Question 3

SELECT
    customer_id,
    SUM(
        CASE
            WHEN txn_type = 'EARN'   THEN points
            WHEN txn_type = 'REDEEM' THEN -points
            ELSE 0
        END
    ) AS final_balance
FROM easy_sql.loyalty_points
GROUP BY customer_id
ORDER BY customer_id;

=========================================================

-- Solution for Question 4

SELECT
    employee_id,
    COUNT(*) OVER (PARTITION BY store_id) AS store_size
FROM easy_sql.store_employees;