-- ================================================================================
--                    SQL MASTERY BOOTCAMP - ASSIGNMENT 1 SOLUTIONS
-- ================================================================================

-- QUESTION 1: Employee Salary Ranking by Department
-- Concept: RANK() window function with PARTITION BY
-- ================================================================================

SELECT 
    emp_name,
    department,
    salary,
    RANK() OVER (
        PARTITION BY department 
        ORDER BY salary DESC
    ) AS salary_rank
FROM assignment_sql.emp_salary
ORDER BY department, salary_rank;

-- Explanation:
-- RANK() assigns the same rank to employees with equal salaries
-- PARTITION BY restarts ranking for each department
-- ORDER BY salary DESC ranks highest salary as 1

-- ================================================================================
-- QUESTION 2: Running Total of Daily Sales
-- Concept: SUM() with window frame
-- ================================================================================

SELECT 
    sale_date,
    amount,
    SUM(amount) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM assignment_sql.daily_sales
ORDER BY sale_date;

-- Explanation:
-- SUM() with ORDER BY creates a cumulative sum
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW is the default frame
-- This adds all previous rows plus current row

-- ================================================================================
-- QUESTION 3: Top 3 Products by Revenue Per Category
-- Concept: DENSE_RANK() with filtering
-- ================================================================================

WITH ranked_products AS (
    SELECT 
        product_name,
        category,
        revenue,
        DENSE_RANK() OVER (
            PARTITION BY category 
            ORDER BY revenue DESC
        ) AS rank
    FROM assignment_sql.product_revenue
)
SELECT product_name, category, revenue, rank
FROM ranked_products
WHERE rank <= 3
ORDER BY category, rank;

-- Explanation:
-- DENSE_RANK() doesn't skip numbers after ties (unlike RANK)
-- CTE allows filtering on the rank column
-- Partitioning by category gives top 3 per category

-- ================================================================================
-- QUESTION 4: Previous and Next Order Amount
-- Concept: LAG() and LEAD() functions
-- ================================================================================

SELECT 
    order_id,
    customer_id,
    order_date,
    amount,
    LAG(amount, 1) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date
    ) AS previous_amount,
    LEAD(amount, 1) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date
    ) AS next_amount
FROM assignment_sql.customer_orders
ORDER BY customer_id, order_date;

-- Explanation:
-- LAG(column, n) returns value from n rows before
-- LEAD(column, n) returns value from n rows after
-- PARTITION BY ensures we only look within same customer

-- ================================================================================
-- QUESTION 5: Moving Average of Stock Prices (3-day window)
-- Concept: AVG() with ROWS frame clause
-- ================================================================================

SELECT 
    symbol,
    trade_date,
    closing_price,
    ROUND(
        AVG(closing_price) OVER (
            PARTITION BY symbol 
            ORDER BY trade_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_3day
FROM assignment_sql.stock_prices
ORDER BY symbol, trade_date;

-- Explanation:
-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW creates a 3-row window
-- AVG() calculates average within that window
-- For first rows, it averages only available rows

-- ================================================================================
-- QUESTION 6: Employees Earning More Than Department Average
-- Concept: Window function for department average
-- ================================================================================

WITH emp_with_avg AS (
    SELECT 
        emp_name,
        department,
        salary,
        ROUND(AVG(salary) OVER (PARTITION BY department), 2) AS dept_avg_salary
    FROM assignment_sql.employees
)
SELECT emp_name, department, salary, dept_avg_salary
FROM emp_with_avg
WHERE salary > dept_avg_salary
ORDER BY department, salary DESC;

-- Explanation:
-- AVG() OVER (PARTITION BY department) calculates avg for each department
-- Filter in WHERE clause to keep only above-average salaries
-- This avoids multiple scans of the table

-- ================================================================================
-- QUESTION 7: Year-over-Year Sales Growth
-- Concept: LAG() for previous period comparison
-- ================================================================================

SELECT 
    product_name,
    year,
    total_sales,
    LAG(total_sales, 1) OVER (
        PARTITION BY product_id 
        ORDER BY year
    ) AS prev_year_sales,
    ROUND(
        (total_sales - LAG(total_sales, 1) OVER (
            PARTITION BY product_id 
            ORDER BY year
        )) * 100.0 / NULLIF(LAG(total_sales, 1) OVER (
            PARTITION BY product_id 
            ORDER BY year
        ), 0), 2
    ) AS yoy_growth_pct
FROM assignment_sql.yearly_sales
ORDER BY product_name, year;

-- Explanation:
-- LAG() gets previous year's sales
-- Growth formula: (current - previous) / previous * 100
-- NULLIF prevents division by zero

-- ================================================================================
-- QUESTION 8: First and Last Purchase Date Per Customer
-- Concept: MIN/MAX window functions
-- ================================================================================

SELECT 
    customer_id,
    MIN(purchase_date) AS first_purchase,
    MAX(purchase_date) AS last_purchase,
    DATEDIFF(MAX(purchase_date), MIN(purchase_date)) AS days_as_customer
FROM assignment_sql.purchases
GROUP BY customer_id
ORDER BY customer_id;

-- Explanation:
-- Simple GROUP BY with MIN/MAX aggregations
-- Date subtraction gives the number of days between dates

-- ================================================================================
-- QUESTION 9: Consecutive Login Streak
-- Concept: Gap and Island problem
-- ================================================================================

WITH numbered_logins AS (
    SELECT 
        user_id,
        login_date,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date) AS rn
    FROM assignment_sql.user_logins
),
login_groups AS (
    SELECT
        user_id,
        login_date,
        DATE_SUB(login_date, INTERVAL rn DAY) AS grp
    FROM numbered_logins
),
streak_counts AS (
    SELECT 
        user_id,
        grp,
        COUNT(*) AS streak_length
    FROM login_groups
    GROUP BY user_id, grp
)
SELECT 
    user_id,
    MAX(streak_length) AS max_streak
FROM streak_counts
GROUP BY user_id
HAVING MAX(streak_length) >= 3
ORDER BY user_id;

-- Explanation:
-- Gap and Island technique: consecutive dates minus row number gives same group
-- Count per group gives streak length
-- Filter for streaks >= 3

-- ================================================================================
-- QUESTION 10: Percentage of Total Sales by Product
-- Concept: SUM() OVER () for total
-- ================================================================================

SELECT 
    product_name,
    sales_amount,
    ROUND(
        sales_amount * 100.0 / SUM(sales_amount) OVER (), 2
    ) AS sales_percentage
FROM assignment_sql.product_sales
ORDER BY sales_amount DESC;

-- Explanation:
-- SUM() OVER () without PARTITION BY gives grand total
-- Divide each row by total to get percentage
-- ORDER BY sales DESC shows highest contributors first

-- ================================================================================
-- QUESTION 11: Row Number with Reset on Category Change
-- Concept: ROW_NUMBER() with PARTITION BY
-- ================================================================================

SELECT 
    product_name,
    category,
    ROW_NUMBER() OVER (
        PARTITION BY category 
        ORDER BY product_name
    ) AS row_num
FROM assignment_sql.products
ORDER BY category, row_num;

-- Explanation:
-- ROW_NUMBER() assigns unique sequential numbers
-- PARTITION BY category resets numbering for each category
-- ORDER BY product_name determines the sequence

-- ================================================================================
-- QUESTION 12: Cumulative Sum with Partition Reset
-- Concept: Running sum with multiple partitions
-- ================================================================================

SELECT 
    salesperson,
    sale_month,
    sale_amount,
    SUM(sale_amount) OVER (
        PARTITION BY salesperson, sale_month 
        ORDER BY sale_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sum
FROM assignment_sql.sales_data
ORDER BY salesperson, sale_month, sale_id;

-- Explanation:
-- PARTITION BY both salesperson and month resets sum for each combination
-- Running sum within each partition

-- ================================================================================
-- QUESTION 13: Find Median Salary Per Department
-- Concept: PERCENTILE_CONT for median
-- ================================================================================

SELECT 
    department,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary) AS median_salary
FROM assignment_sql.dept_salaries
GROUP BY department
ORDER BY department;

-- Explanation:
-- PERCENTILE_CONT(0.5) calculates the median (50th percentile)
-- WITHIN GROUP (ORDER BY salary) specifies the ordering
-- Interpolates between values if necessary

-- ================================================================================
-- QUESTION 14: Nth Highest Salary (Find 3rd Highest)
-- Concept: DENSE_RANK() for Nth position
-- ================================================================================

WITH ranked AS (
    SELECT 
        emp_name,
        department,
        salary,
        DENSE_RANK() OVER (
            PARTITION BY department 
            ORDER BY salary DESC
        ) AS salary_rank
    FROM assignment_sql.emp_salaries
)
SELECT emp_name, department, salary
FROM ranked
WHERE salary_rank = 3
ORDER BY department;

-- Explanation:
-- DENSE_RANK() handles ties properly for Nth highest
-- Filter for rank = 3 to get 3rd highest per department

-- ================================================================================
-- QUESTION 15: Identify Gaps in Sequential Data
-- Concept: Recursive CTE sequence generation
-- ================================================================================

WITH RECURSIVE id_series AS (
    SELECT
        MIN(order_id) AS id,
        MAX(order_id) AS max_id
    FROM assignment_sql.orders

    UNION ALL

    SELECT id + 1, max_id
    FROM id_series
    WHERE id < max_id
)
SELECT id AS missing_order_id
FROM id_series
WHERE id NOT IN (SELECT order_id FROM assignment_sql.orders)
ORDER BY missing_order_id;

-- Explanation:
-- Recursive CTE creates complete sequence from min to max
-- NOT IN finds IDs not present in actual data

-- ================================================================================
-- QUESTION 16: Dense Rank vs Rank Comparison
-- Concept: Understanding RANK vs DENSE_RANK
-- ================================================================================

SELECT 
    student_name,
    score,
    RANK() OVER (ORDER BY score DESC) AS rank,
    DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rank
FROM assignment_sql.student_scores
ORDER BY score DESC;

-- Explanation:
-- RANK: Skips numbers after ties (1,2,2,4,5)
-- DENSE_RANK: No gaps after ties (1,2,2,3,4)
-- Both useful depending on use case

-- ================================================================================
-- QUESTION 17: First Value and Last Value in Window
-- Concept: FIRST_VALUE() and LAST_VALUE() functions
-- ================================================================================

SELECT 
    txn_id,
    customer_id,
    txn_date,
    amount,
    FIRST_VALUE(amount) OVER (
        PARTITION BY customer_id 
        ORDER BY txn_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS first_amount,
    LAST_VALUE(amount) OVER (
        PARTITION BY customer_id 
        ORDER BY txn_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_amount
FROM assignment_sql.transactions
ORDER BY customer_id, txn_date;

-- Explanation:
-- FIRST_VALUE gets first value in window
-- LAST_VALUE needs explicit UNBOUNDED FOLLOWING frame
-- Default frame only goes to CURRENT ROW

-- ================================================================================
-- QUESTION 18: Hierarchical Employee Manager Query
-- Concept: Recursive CTE
-- ================================================================================

WITH RECURSIVE emp_chain AS (
    -- Base case: CEO (no manager)
    SELECT 
        emp_id,
        emp_name,
        manager_id,
        1 AS level,
        CAST(emp_name AS CHAR(1000)) AS hierarchy_path
    FROM assignment_sql.emp_hierarchy
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive case: employees with managers
    SELECT 
        e.emp_id,
        e.emp_name,
        e.manager_id,
        ec.level + 1,
        CONCAT(ec.hierarchy_path, ' -> ', e.emp_name)
    FROM assignment_sql.emp_hierarchy e
    JOIN emp_chain ec ON e.manager_id = ec.emp_id
)
SELECT emp_id, emp_name, level, hierarchy_path
FROM emp_chain
ORDER BY level, emp_id;

-- Explanation:
-- Recursive CTE starts with base case (CEO, no manager)
-- Recursion joins employees to their managers
-- Builds hierarchy path by concatenating names

-- ================================================================================
-- QUESTION 19: Difference from Previous Row
-- Concept: LAG() for row comparison
-- ================================================================================

SELECT 
    city,
    record_date,
    temperature,
    temperature - LAG(temperature) OVER (
        PARTITION BY city 
        ORDER BY record_date
    ) AS temp_change
FROM assignment_sql.weather
ORDER BY city, record_date;

-- Explanation:
-- LAG() gets previous day's temperature
-- Simple subtraction gives the change
-- NULL for first row (no previous value)

-- ================================================================================
-- QUESTION 20: NTILE - Divide Data into Quartiles
-- Concept: NTILE() function
-- ================================================================================

SELECT 
    emp_name,
    salary,
    NTILE(4) OVER (ORDER BY salary DESC) AS quartile
FROM assignment_sql.emp_quartiles
ORDER BY salary DESC;

-- Explanation:
-- NTILE(4) divides data into 4 equal groups
-- Highest salaries get quartile 1
-- Handles uneven distribution automatically

-- ================================================================================
-- QUESTION 21: Pivot Monthly Sales Data
-- Concept: Conditional aggregation for pivot
-- ================================================================================

SELECT 
    product,
    SUM(CASE WHEN month = 'January' THEN sales ELSE 0 END) AS January,
    SUM(CASE WHEN month = 'February' THEN sales ELSE 0 END) AS February,
    SUM(CASE WHEN month = 'March' THEN sales ELSE 0 END) AS March
FROM assignment_sql.monthly_sales
GROUP BY product
ORDER BY product;

-- Explanation:
-- CASE WHEN creates conditional sums
-- Each month becomes a column
-- GROUP BY product creates one row per product

-- ================================================================================
-- QUESTION 22: Find Duplicate Records
-- Concept: COUNT() window function
-- ================================================================================

WITH email_counts AS (
    SELECT 
        customer_id,
        customer_name,
        email,
        COUNT(*) OVER (PARTITION BY email) AS email_count
    FROM assignment_sql.customers
)
SELECT customer_id, customer_name, email
FROM email_counts
WHERE email_count > 1
ORDER BY email, customer_id;

-- Explanation:
-- COUNT() OVER (PARTITION BY email) counts occurrences per email
-- Filter for count > 1 to find duplicates
-- Shows all records with duplicate emails

-- ================================================================================
-- QUESTION 23: Calculate Time Between Events
-- Concept: LEAD() for next event time
-- ================================================================================

SELECT 
    user_id,
    page_name,
    view_time,
    TIMESTAMPDIFF(
        MINUTE,
        view_time,
        LEAD(view_time) OVER (
            PARTITION BY user_id 
            ORDER BY view_time
        )
    ) AS time_on_page_mins
FROM assignment_sql.page_views
ORDER BY user_id, view_time;

-- Explanation:
-- LEAD() gets next page view time
-- Subtract current time to get duration
-- TIMESTAMPDIFF calculates the difference in minutes

-- ================================================================================
-- QUESTION 24: Self Join - Find Employees with Same Salary
-- Concept: Self-join with inequality condition
-- ================================================================================

SELECT 
    e1.emp_name AS employee_1,
    e2.emp_name AS employee_2,
    e1.salary
FROM assignment_sql.emp_pairs e1
JOIN assignment_sql.emp_pairs e2 
    ON e1.salary = e2.salary 
    AND e1.emp_id < e2.emp_id
ORDER BY e1.salary, e1.emp_name;

-- Explanation:
-- Self-join on salary matches employees with same salary
-- e1.emp_id < e2.emp_id prevents duplicate pairs and self-matches
-- Results in unique pairs only

-- ================================================================================
-- QUESTION 25: Rolling Sum (Last 3 Days)
-- Concept: ROWS frame with bounded window
-- ================================================================================

SELECT 
    store_id,
    order_date,
    order_count,
    SUM(order_count) OVER (
        PARTITION BY store_id 
        ORDER BY order_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3day_sum
FROM assignment_sql.store_orders
ORDER BY store_id, order_date;

-- Explanation:
-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW creates 3-row window
-- SUM within that window gives rolling sum
-- Partition by store_id keeps stores separate

-- ================================================================================
-- QUESTION 26: Count Distinct in Window
-- Concept: Simulating COUNT DISTINCT with window
-- ================================================================================

WITH products_seen AS (
    SELECT 
        order_id,
        customer_id,
        product_id,
        order_date,
        DENSE_RANK() OVER (
            PARTITION BY customer_id 
            ORDER BY product_id
        ) AS product_rank,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, product_id 
            ORDER BY order_date
        ) AS product_occurrence
    FROM assignment_sql.cust_orders
)
SELECT 
    order_id,
    customer_id,
    product_id,
    (SELECT COUNT(DISTINCT p2.product_id) 
     FROM assignment_sql.cust_orders p2 
     WHERE p2.customer_id = p.customer_id 
       AND p2.order_date <= p.order_date) AS distinct_products_so_far
FROM assignment_sql.cust_orders p
ORDER BY customer_id, order_date;

-- Explanation:
-- Correlated subquery counts distinct products up to current date
-- Window functions don't directly support COUNT DISTINCT
-- This pattern is common for running distinct counts

-- ================================================================================
-- QUESTION 27: Islands and Gaps Problem
-- Concept: Gap and Island with status filtering
-- ================================================================================

WITH numbered_active_days AS (
    SELECT 
        status_date,
        ROW_NUMBER() OVER (ORDER BY status_date) AS rn
    FROM assignment_sql.server_status
    WHERE is_active = 1
),
active_days AS (
    SELECT
        status_date,
        DATE_SUB(status_date, INTERVAL rn DAY) AS island_group
    FROM numbered_active_days
)
SELECT 
    MIN(status_date) AS period_start,
    MAX(status_date) AS period_end,
    COUNT(*) AS days_active
FROM active_days
GROUP BY island_group
ORDER BY period_start;

-- Explanation:
-- Filter for active days only
-- Subtract row number from date to create groups
-- Consecutive dates get same group value
-- Aggregate to get period boundaries

-- ================================================================================
-- QUESTION 28: Percent Rank and Cumulative Distribution
-- Concept: PERCENT_RANK() and CUME_DIST()
-- ================================================================================

SELECT 
    emp_name,
    salary,
    ROUND(PERCENT_RANK() OVER (ORDER BY salary), 2) AS percent_rank,
    ROUND(CUME_DIST() OVER (ORDER BY salary), 2) AS cume_dist
FROM assignment_sql.emp_dist
ORDER BY salary;

-- Explanation:
-- PERCENT_RANK: (rank - 1) / (total rows - 1)
-- CUME_DIST: rank / total rows (cumulative distribution)
-- Both return values between 0 and 1

-- ================================================================================
-- QUESTION 29: Window Frame - ROWS vs RANGE
-- Concept: Understanding ROWS vs RANGE behavior
-- ================================================================================

SELECT 
    id,
    value,
    SUM(value) OVER (
        ORDER BY value
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rows_sum,
    SUM(value) OVER (
        ORDER BY value
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS range_sum
FROM assignment_sql.frame_demo
ORDER BY id;

-- Explanation:
-- ROWS: Physical rows, each row processed individually
-- RANGE: Logical range, includes all rows with same ORDER BY value
-- When values are equal, RANGE includes all of them at once
-- This shows different results when duplicates exist

-- ================================================================================
-- QUESTION 30: Complex CTE with Multiple Steps
-- Concept: Multi-step CTE for complex analysis
-- ================================================================================

WITH monthly_customer_sales AS (
    -- Step 1: Aggregate sales by month and customer
    SELECT 
        DATE_FORMAT(txn_date, '%Y-%m') AS month,
        customer_id,
        SUM(amount) AS customer_spend
    FROM assignment_sql.sales_transactions
    GROUP BY DATE_FORMAT(txn_date, '%Y-%m'), customer_id
),
monthly_totals AS (
    -- Step 2: Calculate monthly totals
    SELECT 
        month,
        SUM(customer_spend) AS monthly_total
    FROM monthly_customer_sales
    GROUP BY month
),
ranked_customers AS (
    -- Step 3: Rank customers by spend within each month
    SELECT 
        mcs.month,
        mcs.customer_id AS top_customer_id,
        mcs.customer_spend,
        mt.monthly_total,
        RANK() OVER (PARTITION BY mcs.month ORDER BY mcs.customer_spend DESC) AS spend_rank
    FROM monthly_customer_sales mcs
    JOIN monthly_totals mt ON mcs.month = mt.month
)
-- Step 4: Select top customer per month with percentage
SELECT 
    month,
    top_customer_id,
    customer_spend,
    monthly_total,
    ROUND(customer_spend * 100.0 / monthly_total, 2) AS pct_of_monthly
FROM ranked_customers
WHERE spend_rank = 1
ORDER BY month;

-- Explanation:
-- CTE 1: Aggregates sales by customer and month
-- CTE 2: Calculates total sales per month
-- CTE 3: Ranks customers by spend within each month
-- Final: Selects top spender with percentage calculation
-- Shows power of breaking complex logic into manageable steps

-- ================================================================================
--                              END OF SOLUTIONS
-- ================================================================================
