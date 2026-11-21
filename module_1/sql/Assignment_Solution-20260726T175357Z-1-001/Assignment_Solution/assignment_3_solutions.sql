-- ================================================================================
--                    SQL MASTERY BOOTCAMP - ASSIGNMENT 3 SOLUTIONS
-- ================================================================================

-- QUESTION 1: Customer Retention Analysis
-- Concept: Month-over-month customer overlap analysis
-- ================================================================================

WITH monthly_customers AS (
    SELECT DISTINCT
        DATE_FORMAT(purchase_date, '%Y-%m') AS month,
        customer_id
    FROM assignment_sql.purchases_ret
),
retention_calc AS (
    SELECT 
        curr.month,
        COUNT(DISTINCT curr.customer_id) AS total_customers,
        COUNT(DISTINCT prev.customer_id) AS retained_customers
    FROM monthly_customers curr
    LEFT JOIN monthly_customers prev 
        ON curr.customer_id = prev.customer_id
        AND prev.month = DATE_FORMAT(
            DATE_SUB(STR_TO_DATE(CONCAT(curr.month, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH),
            '%Y-%m'
        )
    GROUP BY curr.month
)
SELECT 
    month,
    total_customers,
    retained_customers,
    ROUND(retained_customers * 100.0 / NULLIF(total_customers, 0), 2) AS retention_rate
FROM retention_calc
ORDER BY month;

-- Explanation:
-- Get distinct customers per month
-- Self-join to find customers who also bought previous month
-- Retention rate = retained / total * 100

-- ================================================================================
-- QUESTION 2: Inventory Turnover Calculation
-- Concept: COGS / Average Inventory
-- ================================================================================

WITH cogs AS (
    SELECT 
        product_id,
        SUM(quantity_sold * unit_cost) AS total_cogs
    FROM assignment_sql.sales_inv
    GROUP BY product_id
),
avg_inventory AS (
    SELECT 
        product_id,
        AVG(quantity * unit_cost) AS avg_inv_value
    FROM assignment_sql.inventory
    GROUP BY product_id
)
SELECT 
    c.product_id,
    c.total_cogs AS cogs,
    ROUND(ai.avg_inv_value, 0) AS avg_inventory,
    ROUND(c.total_cogs / NULLIF(ai.avg_inv_value, 0), 2) AS turnover_ratio
FROM cogs c
JOIN avg_inventory ai ON c.product_id = ai.product_id
ORDER BY c.product_id;

-- Explanation:
-- COGS = sum of (quantity sold × unit cost)
-- Average inventory = average of (inventory × cost)
-- Turnover = COGS / Average Inventory

-- ================================================================================
-- QUESTION 3: Funnel Analysis
-- Concept: Conversion through stages
-- ================================================================================

WITH funnel_counts AS (
    SELECT 
        event_type,
        COUNT(DISTINCT user_id) AS user_count
    FROM assignment_sql.user_events
    GROUP BY event_type
),
visit_count AS (
    SELECT user_count FROM funnel_counts WHERE event_type = 'Visit'
)
SELECT 
    fc.event_type,
    fc.user_count,
    ROUND(fc.user_count * 100.0 / vc.user_count, 2) AS conversion_rate
FROM funnel_counts fc
CROSS JOIN visit_count vc
ORDER BY 
    CASE fc.event_type 
        WHEN 'Visit' THEN 1 
        WHEN 'Signup' THEN 2 
        WHEN 'Purchase' THEN 3 
    END;

-- Explanation:
-- Count unique users at each stage
-- Calculate percentage relative to Visit (top of funnel)
-- Order by funnel stage

-- ================================================================================
-- QUESTION 4: Session Analysis
-- Concept: Gap detection for session boundaries
-- ================================================================================

WITH time_diffs AS (
    SELECT 
        user_id,
        page_name,
        view_time,
        LAG(view_time) OVER (PARTITION BY user_id ORDER BY view_time) AS prev_time,
        CASE 
            WHEN LAG(view_time) OVER (PARTITION BY user_id ORDER BY view_time) IS NULL 
                 OR TIMESTAMPDIFF(
                     MINUTE,
                     LAG(view_time) OVER (PARTITION BY user_id ORDER BY view_time),
                     view_time
                 ) > 30
            THEN 1 
            ELSE 0 
        END AS is_new_session
    FROM assignment_sql.page_views_sess
),
session_groups AS (
    SELECT 
        user_id,
        page_name,
        view_time,
        SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY view_time) AS session_id
    FROM time_diffs
)
SELECT 
    user_id,
    session_id,
    MIN(view_time) AS session_start,
    MAX(view_time) AS session_end,
    COUNT(*) AS page_count
FROM session_groups
GROUP BY user_id, session_id
ORDER BY user_id, session_id;

-- Explanation:
-- Identify new sessions when gap > 30 minutes
-- Running sum of session flags creates session IDs
-- Aggregate to get session boundaries and page counts

-- ================================================================================
-- QUESTION 5: Market Basket Analysis - Frequently Bought Together
-- Concept: Self-join for pair analysis
-- ================================================================================

SELECT 
    o1.product_name AS product_1,
    o2.product_name AS product_2,
    COUNT(DISTINCT o1.order_id) AS times_together
FROM assignment_sql.order_items_mba o1
JOIN assignment_sql.order_items_mba o2 
    ON o1.order_id = o2.order_id 
    AND o1.product_id < o2.product_id
GROUP BY o1.product_name, o2.product_name
ORDER BY times_together DESC, product_1, product_2;

-- Explanation:
-- Self-join on same order finds co-purchased products
-- product_id < condition prevents duplicate pairs
-- Count distinct orders gives frequency

-- ================================================================================
-- QUESTION 6: Time Series Gap Filling
-- Concept: Recursive CTE date series with LEFT JOIN
-- ================================================================================

WITH RECURSIVE date_range AS (
    SELECT
        MIN(sale_date) AS sale_date,
        MAX(sale_date) AS end_date
    FROM assignment_sql.daily_sales_gap

    UNION ALL

    SELECT DATE_ADD(sale_date, INTERVAL 1 DAY), end_date
    FROM date_range
    WHERE sale_date < end_date
)
SELECT 
    dr.sale_date,
    COALESCE(ds.amount, 0) AS amount
FROM date_range dr
LEFT JOIN assignment_sql.daily_sales_gap ds ON dr.sale_date = ds.sale_date
ORDER BY dr.sale_date;

-- Explanation:
-- Recursive CTE creates complete date sequence
-- LEFT JOIN attaches actual sales data
-- COALESCE fills gaps with 0

-- ================================================================================
-- QUESTION 7: Cohort Analysis - User Signup Cohorts
-- Concept: Cohort tracking over time
-- ================================================================================

WITH user_cohorts AS (
    SELECT 
        user_id,
        STR_TO_DATE(DATE_FORMAT(signup_date, '%Y-%m-01'), '%Y-%m-%d') AS cohort_month
    FROM assignment_sql.users_cohort
),
activity_months AS (
    SELECT 
        a.user_id,
        uc.cohort_month,
        STR_TO_DATE(DATE_FORMAT(a.activity_date, '%Y-%m-01'), '%Y-%m-%d') AS activity_month,
        TIMESTAMPDIFF(
            MONTH,
            uc.cohort_month,
            STR_TO_DATE(DATE_FORMAT(a.activity_date, '%Y-%m-01'), '%Y-%m-%d')
        ) AS months_since_signup
    FROM assignment_sql.user_activity a
    JOIN user_cohorts uc ON a.user_id = uc.user_id
)
SELECT 
    DATE_FORMAT(cohort_month, '%Y-%m') AS cohort_month,
    COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN user_id END) AS month_0,
    COUNT(DISTINCT CASE WHEN months_since_signup = 1 THEN user_id END) AS month_1,
    COUNT(DISTINCT CASE WHEN months_since_signup = 2 THEN user_id END) AS month_2
FROM activity_months
GROUP BY cohort_month
ORDER BY cohort_month;

-- Explanation:
-- Assign each user to their signup cohort
-- Calculate months since signup for each activity
-- Pivot to show activity by relative month

-- ================================================================================
-- QUESTION 8: Detect Suspicious Transactions
-- Concept: Statistical outlier detection
-- ================================================================================

WITH customer_stats AS (
    SELECT 
        customer_id,
        AVG(amount) AS avg_amt,
        STDDEV(amount) AS std_dev
    FROM assignment_sql.transactions_susp
    GROUP BY customer_id
)
SELECT 
    t.txn_id,
    t.customer_id,
    t.amount,
    ROUND(cs.avg_amt, 2) AS avg_amt,
    ROUND(cs.std_dev, 2) AS std_dev,
    'Yes' AS is_suspicious
FROM assignment_sql.transactions_susp t
JOIN customer_stats cs ON t.customer_id = cs.customer_id
WHERE t.amount > cs.avg_amt + 2 * cs.std_dev
   OR t.amount < cs.avg_amt - 2 * cs.std_dev
ORDER BY t.txn_id;

-- Explanation:
-- Calculate mean and standard deviation per customer
-- Flag transactions > 2 std deviations from mean
-- Common statistical outlier detection method

-- ================================================================================
-- QUESTION 9: Product Recommendation - Customers Who Bought X Also Bought Y
-- Concept: Filtered aggregation for recommendations
-- ================================================================================

WITH laptop_buyers AS (
    SELECT DISTINCT customer_id
    FROM assignment_sql.purchases_rec
    WHERE product_name = 'Laptop'
)
SELECT 
    p.product_name,
    COUNT(DISTINCT p.customer_id) AS laptop_buyers_count
FROM assignment_sql.purchases_rec p
JOIN laptop_buyers lb ON p.customer_id = lb.customer_id
WHERE p.product_name != 'Laptop'
GROUP BY p.product_name
ORDER BY laptop_buyers_count DESC, p.product_name;

-- Explanation:
-- Find customers who bought Laptop
-- Find other products those customers bought
-- Count and rank by frequency

-- ================================================================================
-- QUESTION 10: Sliding Window - 7 Day Active Users
-- Concept: Rolling distinct count
-- ================================================================================

WITH login_dates AS (
    SELECT DISTINCT login_date, user_id
    FROM assignment_sql.user_logins_7d
)
SELECT 
    ld.login_date,
    (
        SELECT COUNT(DISTINCT user_id)
        FROM assignment_sql.user_logins_7d
        WHERE login_date BETWEEN DATE_SUB(ld.login_date, INTERVAL 6 DAY) AND ld.login_date
    ) AS unique_users_7day
FROM (SELECT DISTINCT login_date FROM login_dates) ld
ORDER BY ld.login_date;

-- Explanation:
-- For each date, count distinct users in 7-day window
-- Correlated subquery handles rolling distinct count
-- Window functions don't support COUNT DISTINCT directly

-- ================================================================================
-- QUESTION 11: Revenue Attribution by First Touch
-- Concept: First-touch attribution model
-- ================================================================================

WITH first_touch AS (
    SELECT 
        customer_id,
        channel,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY touch_date) AS touch_order
    FROM assignment_sql.marketing_touches
)
SELECT 
    ft.channel,
    COUNT(DISTINCT ft.customer_id) AS customer_count,
    SUM(cr.total_revenue) AS total_revenue
FROM first_touch ft
JOIN assignment_sql.customer_revenue cr ON ft.customer_id = cr.customer_id
WHERE ft.touch_order = 1
GROUP BY ft.channel
ORDER BY ft.channel;

-- Explanation:
-- ROW_NUMBER identifies first touch per customer
-- Filter to first touch only
-- Aggregate revenue by attribution channel

-- ================================================================================
-- QUESTION 12: Churn Prediction - Inactive Customers
-- Concept: Identifying dormant customers
-- ================================================================================

WITH customer_last_purchase AS (
    SELECT 
        customer_id,
        MAX(purchase_date) AS last_purchase_date
    FROM assignment_sql.customer_purchases
    GROUP BY customer_id
)
SELECT 
    customer_id,
    last_purchase_date,
    DATEDIFF('2024-03-01', last_purchase_date) AS days_since_last
FROM customer_last_purchase
WHERE DATEDIFF('2024-03-01', last_purchase_date) > 60
ORDER BY days_since_last DESC;

-- Explanation:
-- Find last purchase date per customer
-- Calculate days since last purchase
-- Filter for 60+ days inactive

-- ================================================================================
-- QUESTION 13: Price Elasticity Analysis
-- Concept: Percentage change calculations
-- ================================================================================

WITH price_changes AS (
    SELECT 
        product_id,
        price_date,
        price,
        quantity_sold,
        LAG(price) OVER (PARTITION BY product_id ORDER BY price_date) AS prev_price,
        LAG(quantity_sold) OVER (PARTITION BY product_id ORDER BY price_date) AS prev_qty
    FROM assignment_sql.price_history
)
SELECT 
    product_id,
    price_date,
    ROUND((price - prev_price) * 100.0 / NULLIF(prev_price, 0), 2) AS price_change,
    ROUND((quantity_sold - prev_qty) * 100.0 / NULLIF(prev_qty, 0), 2) AS qty_change,
    ROUND(
        ((quantity_sold - prev_qty) * 100.0 / NULLIF(prev_qty, 0)) /
        NULLIF((price - prev_price) * 100.0 / NULLIF(prev_price, 0), 0),
        2
    ) AS elasticity
FROM price_changes
WHERE prev_price IS NOT NULL
ORDER BY product_id, price_date;

-- Explanation:
-- Calculate percentage change in price and quantity
-- Elasticity = % change in quantity / % change in price
-- Negative elasticity indicates normal demand curve

-- ================================================================================
-- QUESTION 14: A/B Test Analysis
-- Concept: Statistical comparison between groups
-- ================================================================================

SELECT 
    test_group,
    COUNT(*) AS total_users,
    SUM(converted) AS conversions,
    ROUND(SUM(converted) * 100.0 / COUNT(*), 2) AS conversion_rate
FROM assignment_sql.ab_test
GROUP BY test_group
ORDER BY test_group;

-- Explanation:
-- Group by test variant
-- Calculate conversion rate per group
-- Compare rates to determine winner

-- ================================================================================
-- QUESTION 15: Revenue by Customer Lifetime Value Tier
-- Concept: Customer segmentation
-- ================================================================================

SELECT 
    CASE 
        WHEN total_spent < 1000 THEN 'Low'
        WHEN total_spent <= 5000 THEN 'Medium'
        ELSE 'High'
    END AS ltv_tier,
    COUNT(*) AS customer_count,
    SUM(total_spent) AS total_revenue
FROM assignment_sql.customer_ltv
GROUP BY 
    CASE 
        WHEN total_spent < 1000 THEN 'Low'
        WHEN total_spent <= 5000 THEN 'Medium'
        ELSE 'High'
    END
ORDER BY 
    CASE 
        WHEN ltv_tier = 'Low' THEN 1
        WHEN ltv_tier = 'Medium' THEN 2
        ELSE 3
    END;

-- Explanation:
-- CASE WHEN creates tier buckets
-- Aggregate by tier
-- Custom ORDER BY for logical tier ordering

-- ================================================================================
-- QUESTION 16: Overlap Detection - Booking Conflicts
-- Concept: Date range overlap detection
-- ================================================================================

SELECT 
    b1.room_id,
    b1.booking_id AS booking1_id,
    b1.guest_name AS guest1,
    b2.booking_id AS booking2_id,
    b2.guest_name AS guest2
FROM assignment_sql.room_bookings b1
JOIN assignment_sql.room_bookings b2 
    ON b1.room_id = b2.room_id
    AND b1.booking_id < b2.booking_id
    AND b1.start_date < b2.end_date
    AND b1.end_date > b2.start_date
ORDER BY b1.room_id, b1.booking_id;

-- Explanation:
-- Self-join on same room
-- Overlap condition: start1 < end2 AND end1 > start2
-- booking_id comparison prevents self-match and duplicates

-- ================================================================================
-- QUESTION 17: Time-Based Comparison - Same Day Last Week
-- Concept: LAG with offset for weekly comparison
-- ================================================================================

WITH daily_with_weekly AS (
    SELECT 
        sale_date,
        amount,
        LAG(amount, 7) OVER (ORDER BY sale_date) AS last_week_amount
    FROM assignment_sql.weekly_sales
)
SELECT 
    sale_date,
    amount,
    last_week_amount,
    CASE 
        WHEN last_week_amount IS NOT NULL 
        THEN ROUND((amount - last_week_amount) * 100.0 / last_week_amount, 2)
        ELSE NULL 
    END AS week_over_week
FROM daily_with_weekly
ORDER BY sale_date;

-- Explanation:
-- LAG(amount, 7) looks back 7 rows for same day last week
-- Calculate percentage change
-- NULL when no prior week data

-- ================================================================================
-- QUESTION 18: Materialized View - Pre-aggregated Sales
-- Concept: Query suitable for materialization
-- ================================================================================

SELECT 
    sale_date,
    category,
    SUM(quantity) AS total_quantity,
    SUM(quantity * unit_price) AS total_sales
FROM assignment_sql.sales_detail
GROUP BY sale_date, category
ORDER BY sale_date, category;

-- For creating materialized view:
-- CREATE MATERIALIZED VIEW mv_daily_sales AS
-- SELECT ... (above query)
-- WITH DATA;

-- Explanation:
-- Pre-aggregate at daily + category level
-- Materialized view stores results physically
-- Refresh periodically for updated data

-- ================================================================================
-- QUESTION 19: Dynamic Pivot - Sales by Quarter
-- Concept: Conditional aggregation for quarterly pivot
-- ================================================================================

SELECT 
    product_name,
    SUM(CASE WHEN EXTRACT(QUARTER FROM sale_date) = 1 THEN amount ELSE 0 END) AS Q1,
    SUM(CASE WHEN EXTRACT(QUARTER FROM sale_date) = 2 THEN amount ELSE 0 END) AS Q2,
    SUM(CASE WHEN EXTRACT(QUARTER FROM sale_date) = 3 THEN amount ELSE 0 END) AS Q3,
    SUM(CASE WHEN EXTRACT(QUARTER FROM sale_date) = 4 THEN amount ELSE 0 END) AS Q4
FROM assignment_sql.quarterly_data
GROUP BY product_id, product_name
ORDER BY product_name;

-- Explanation:
-- EXTRACT(QUARTER) gets quarter number (1-4)
-- CASE WHEN creates conditional sums per quarter
-- Results in pivot table format

-- ================================================================================
-- QUESTION 20: Finding Patterns - Consecutive Increases
-- Concept: Gap and island for trend detection
-- ================================================================================

WITH daily_changes AS (
    SELECT 
        symbol,
        trade_date,
        closing_price,
        closing_price > LAG(closing_price) OVER (
            PARTITION BY symbol ORDER BY trade_date
        ) AS is_increase
    FROM assignment_sql.stock_daily
),
increase_groups AS (
    SELECT 
        symbol,
        trade_date,
        is_increase,
        SUM(CASE WHEN NOT is_increase OR is_increase IS NULL THEN 1 ELSE 0 END) 
            OVER (PARTITION BY symbol ORDER BY trade_date) AS grp
    FROM daily_changes
)
SELECT 
    symbol,
    COUNT(*) AS consecutive_days
FROM increase_groups
WHERE is_increase = true
GROUP BY symbol, grp
HAVING COUNT(*) >= 3
ORDER BY consecutive_days DESC;

-- Explanation:
-- Flag days with price increase
-- Create groups using gap-and-island technique
-- Count consecutive increases per group

-- ================================================================================
-- QUESTION 21: Multi-Level Hierarchy Sum
-- Concept: Recursive CTE for hierarchy traversal
-- ================================================================================

WITH RECURSIVE hierarchy AS (
    SELECT 
        dept_id,
        dept_name,
        parent_id,
        revenue,
        dept_id AS root_id
    FROM assignment_sql.org_hierarchy
    
    UNION ALL
    
    SELECT 
        o.dept_id,
        o.dept_name,
        o.parent_id,
        o.revenue,
        h.root_id
    FROM assignment_sql.org_hierarchy o
    JOIN hierarchy h ON o.parent_id = h.dept_id
)
SELECT 
    o.dept_name,
    o.revenue AS direct_revenue,
    (SELECT SUM(h.revenue) 
     FROM hierarchy h 
     WHERE h.root_id = o.dept_id) AS total_revenue
FROM assignment_sql.org_hierarchy o
ORDER BY total_revenue DESC;

-- Explanation:
-- Recursive CTE traverses hierarchy downward
-- Tracks root_id to identify all descendants
-- Sum revenue for each node including descendants

-- ================================================================================
-- QUESTION 22: Deduplication with Priority
-- Concept: ROW_NUMBER with custom ordering
-- ================================================================================

WITH ranked_customers AS (
    SELECT 
        customer_id,
        customer_name,
        email,
        status,
        ROW_NUMBER() OVER (
            PARTITION BY email 
            ORDER BY CASE WHEN status = 'Premium' THEN 1 ELSE 2 END,
                     created_date DESC
        ) AS rn
    FROM assignment_sql.customer_dupes
)
SELECT customer_id, customer_name, email, status
FROM ranked_customers
WHERE rn = 1
ORDER BY customer_id;

-- Explanation:
-- Partition by email to handle duplicates
-- Order by status (Premium first) then date
-- Keep only first record per email

-- ================================================================================
-- QUESTION 23: Running Balance Calculation
-- Concept: Conditional running sum
-- ================================================================================

SELECT 
    account_id,
    txn_date,
    txn_type,
    amount,
    SUM(
        CASE 
            WHEN txn_type = 'CREDIT' THEN amount 
            ELSE -amount 
        END
    ) OVER (
        PARTITION BY account_id 
        ORDER BY txn_date, txn_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM assignment_sql.bank_transactions
ORDER BY account_id, txn_date, txn_id;

-- Explanation:
-- CREDIT adds to balance, DEBIT subtracts
-- Running sum maintains cumulative balance
-- Partition by account for separate balances

-- ================================================================================
-- QUESTION 24: Median Calculation Without Built-in Function
-- Concept: Manual median using ROW_NUMBER
-- ================================================================================

WITH ranked_salaries AS (
    SELECT 
        department,
        salary,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary) AS rn,
        COUNT(*) OVER (PARTITION BY department) AS cnt
    FROM assignment_sql.emp_median
)
SELECT 
    department,
    AVG(salary) AS median_salary
FROM ranked_salaries
WHERE rn IN (FLOOR((cnt + 1) / 2.0), CEIL((cnt + 1) / 2.0))
GROUP BY department
ORDER BY department;

-- Explanation:
-- ROW_NUMBER orders salaries within department
-- For odd count: middle row
-- For even count: average of two middle rows
-- FLOOR and CEIL handle both cases

-- ================================================================================
-- QUESTION 25: Customer Segmentation - RFM Analysis
-- Concept: Recency, Frequency, Monetary scoring
-- ================================================================================

WITH rfm_data AS (
    SELECT 
        customer_id,
        DATEDIFF('2024-02-01', MAX(purchase_date)) AS recency,
        COUNT(*) AS frequency,
        SUM(amount) AS monetary
    FROM assignment_sql.customer_rfm
    GROUP BY customer_id
)
SELECT 
    customer_id,
    recency,
    frequency,
    monetary,
    CASE 
        WHEN recency <= 7 AND frequency >= 3 AND monetary >= 1000 THEN 'Champion'
        WHEN recency <= 14 AND frequency >= 2 THEN 'Medium'
        WHEN recency <= 7 AND frequency = 1 THEN 'New'
        ELSE 'At Risk'
    END AS segment
FROM rfm_data
ORDER BY customer_id;

-- Explanation:
-- Recency: days since last purchase
-- Frequency: number of purchases
-- Monetary: total spend
-- CASE creates segments based on RFM values

-- ================================================================================
-- QUESTION 26: Moving Sum with Custom Window
-- Concept: Frame clause for rolling sum
-- ================================================================================

SELECT 
    sale_date,
    amount,
    SUM(amount) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_sum_3
FROM assignment_sql.sales_moving
ORDER BY sale_date;

-- Explanation:
-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW = 3-day window
-- SUM within window gives moving sum
-- First rows have smaller windows

-- ================================================================================
-- QUESTION 27: Gap Analysis - Finding Missing Entries
-- Concept: Recursive CTE for complete sequence
-- ================================================================================

WITH RECURSIVE date_range AS (
    SELECT 
        MIN(order_date) AS start_date,
        MAX(order_date) AS end_date
    FROM assignment_sql.order_gaps
),
all_dates AS (
    SELECT start_date AS date_val
    FROM date_range

    UNION ALL

    SELECT DATE_ADD(ad.date_val, INTERVAL 1 DAY)
    FROM all_dates ad
    CROSS JOIN date_range dr
    WHERE ad.date_val < dr.end_date
)
SELECT date_val AS missing_date
FROM all_dates
WHERE date_val NOT IN (
    SELECT DISTINCT order_date 
    FROM assignment_sql.order_gaps
)
ORDER BY missing_date;

-- Explanation:
-- Generate complete date sequence
-- Find dates not in actual orders
-- These are the gap days

-- ================================================================================
-- QUESTION 28: Cumulative Distribution
-- Concept: Running percentage of total
-- ================================================================================

SELECT 
    product_name,
    sales,
    ROUND(sales * 100.0 / SUM(sales) OVER (), 2) AS pct_of_total,
    ROUND(
        SUM(sales) OVER (ORDER BY sales DESC) * 100.0 / 
        SUM(sales) OVER (), 
        2
    ) AS cumulative_pct
FROM assignment_sql.product_cumulative
ORDER BY sales DESC;

-- Explanation:
-- pct_of_total: individual product percentage
-- cumulative_pct: running sum percentage
-- Useful for Pareto analysis (80/20 rule)

-- ================================================================================
-- QUESTION 29: Complex Filter with CASE and Aggregation
-- Concept: Tiered discount calculation
-- ================================================================================

SELECT 
    loyalty_tier,
    SUM(order_amount) AS gross_amount,
    SUM(
        order_amount * 
        CASE loyalty_tier
            WHEN 'Gold' THEN 0.20
            WHEN 'Silver' THEN 0.10
            WHEN 'Bronze' THEN 0.05
            ELSE 0
        END
    ) AS discount_amt,
    SUM(
        order_amount * 
        (1 - CASE loyalty_tier
            WHEN 'Gold' THEN 0.20
            WHEN 'Silver' THEN 0.10
            WHEN 'Bronze' THEN 0.05
            ELSE 0
        END)
    ) AS net_amount
FROM assignment_sql.orders_loyalty
GROUP BY loyalty_tier
ORDER BY gross_amount DESC;

-- Explanation:
-- CASE assigns discount rate by tier
-- Calculate discount and net amounts
-- Aggregate by loyalty tier

-- ================================================================================
-- QUESTION 30: Comprehensive Report - Order Analytics Dashboard
-- Concept: Multiple metrics in single query
-- ================================================================================

SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    product_category,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
    SUM(amount) AS total_amount,
    SUM(CASE WHEN status = 'Completed' THEN amount ELSE 0 END) AS completed_amount,
    ROUND(AVG(amount), 2) AS avg_order
FROM assignment_sql.order_analytics
GROUP BY DATE_FORMAT(order_date, '%Y-%m'), product_category
ORDER BY month, product_category;

-- Explanation:
-- Multiple conditional aggregations in one query
-- Calculates various metrics simultaneously
-- Groups by month and category for dashboard view

-- ================================================================================
--                              END OF SOLUTIONS
-- ================================================================================
