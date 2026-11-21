-- Self join

CREATE TABLE customer_orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    customer_name VARCHAR(100),
    order_date DATE,
    order_amount DECIMAL(10,2)
);

INSERT INTO customer_orders
(order_id, customer_id, customer_name, order_date, order_amount)
VALUES
(1, 101, 'Amit Sharma', '2026-06-01', 1200),
(2, 101, 'Amit Sharma', '2026-06-05', 800),
(3, 101, 'Amit Sharma', '2026-06-20', 1500),
(4, 102, 'Priya Mehta', '2026-06-02', 2000),
(5, 102, 'Priya Mehta', '2026-06-10', 2200),
(6, 103, 'Rahul Verma', '2026-06-03', 700),
(7, 103, 'Rahul Verma', '2026-06-08', 900),
(8, 103, 'Rahul Verma', '2026-06-12', 1100),
(9, 104, 'Sneha Kapoor', '2026-06-04', 3000),
(10, 105, 'Karan Singh', '2026-06-06', 500);


-- Write an SQL query to find all customers who placed another order within 7 days of any previous order
SELECT
    o1.customer_id,
    o1.customer_name,
    o1.order_id AS first_order_id,
    o1.order_date AS first_order_date,
    o2.order_id AS next_order_id,
    o2.order_date AS next_order_date,
    DATEDIFF(o2.order_date, o1.order_date) AS days_between_orders
FROM customer_orders o1
INNER JOIN customer_orders o2
    ON o1.customer_id = o2.customer_id
   AND o1.order_id < o2.order_id
   AND DATEDIFF(o2.order_date, o1.order_date) BETWEEN 1 AND 7
ORDER BY o1.customer_id, o1.order_date;

-- Optimized solution for trips data without correlated subquery
SELECT
    c.trip_id,
    c.driver_name,
    c.city,
    c.trip_amount
FROM cab_trips c
JOIN (
    SELECT
        city,
        AVG(trip_amount) AS avg_city_amount
    FROM cab_trips
    GROUP BY city
) city_avg
    ON c.city = city_avg.city and c.trip_amount > city_avg.avg_city_amount;

-- Exists, NOT Exists
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    user_name VARCHAR(100),
    plan_type VARCHAR(30),
    signup_date DATE
);

CREATE TABLE feature_usage (
    usage_id INT PRIMARY KEY,
    user_id INT,
    feature_name VARCHAR(100),
    usage_date DATE,
    usage_count INT
);

INSERT INTO users
(user_id, user_name, plan_type, signup_date)
VALUES
(1, 'Amit Sharma', 'Free', '2026-05-01'),
(2, 'Priya Mehta', 'Pro', '2026-05-03'),
(3, 'Rahul Verma', 'Pro', '2026-05-05'),
(4, 'Sneha Kapoor', 'Enterprise', '2026-05-07'),
(5, 'Karan Singh', 'Free', '2026-05-10'),
(6, 'Neha Gupta', 'Pro', '2026-05-12'),
(7, 'Rohit Jain', 'Enterprise', '2026-05-15'),
(8, 'Anjali Rao', 'Free', '2026-05-18');

INSERT INTO feature_usage
(usage_id, user_id, feature_name, usage_date, usage_count)
VALUES
(101, 1, 'Dashboard', '2026-06-01', 5),
(102, 1, 'Report Export', '2026-06-03', 2),
(103, 2, 'Dashboard', '2026-06-01', 8),
(104, 2, 'AI Insights', '2026-06-05', 4),
(105, 2, 'Report Export', '2026-06-07', 3),
(106, 3, 'Dashboard', '2026-06-02', 6),
(107, 4, 'Dashboard', '2026-06-01', 10),
(108, 4, 'AI Insights', '2026-06-04', 7),
(109, 4, 'API Access', '2026-06-06', 12),
(110, 6, 'Report Export', '2026-06-03', 2),
(111, 7, 'Dashboard', '2026-06-02', 9),
(112, 7, 'API Access', '2026-06-08', 15);

-- Find users who have used the AI Insights feature at least once.
SELECT
    u.user_id,
    u.user_name,
    u.plan_type
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM feature_usage f
    WHERE f.user_id = u.user_id
      AND f.feature_name = 'AI Insights'
);

-- Find users who have never used the AI Insights feature.
SELECT
    u.user_id,
    u.user_name,
    u.plan_type
FROM users u
WHERE NOT EXISTS (
    SELECT 1
    FROM feature_usage f
    WHERE f.user_id = u.user_id
      AND f.feature_name = 'AI Insights'
);

-- Find Pro or Enterprise users who have used both: AI Insights and Report Export
SELECT
    u.user_id,
    u.user_name,
    u.plan_type
FROM users u
WHERE u.plan_type IN ('Pro', 'Enterprise')
  AND EXISTS (
        SELECT 1
        FROM feature_usage f
        WHERE f.user_id = u.user_id
          AND f.feature_name = 'AI Insights'
  )
  AND EXISTS (
        SELECT 1
        FROM feature_usage f
        WHERE f.user_id = u.user_id
          AND f.feature_name = 'Report Export'
  );


-- ANY and ALL operation
CREATE TABLE cluster_costs (
    cluster_id INT PRIMARY KEY,
    cluster_name VARCHAR(100),
    environment VARCHAR(30),
    cloud_provider VARCHAR(30),
    workload_type VARCHAR(50),
    daily_cost DECIMAL(10,2)
);

INSERT INTO cluster_costs
(cluster_id, cluster_name, environment, cloud_provider, workload_type, daily_cost)
VALUES
(1, 'prod-etl-small', 'Production', 'AWS', 'Batch ETL', 420),
(2, 'prod-etl-medium', 'Production', 'AWS', 'Batch ETL', 650),
(3, 'prod-streaming-main', 'Production', 'AWS', 'Streaming', 900),
(4, 'dev-etl-test', 'Development', 'AWS', 'Batch ETL', 300),
(5, 'dev-spark-heavy', 'Development', 'AWS', 'Batch ETL', 700),
(6, 'qa-pipeline-validation', 'QA', 'AWS', 'Batch ETL', 500),
(7, 'analytics-adhoc-1', 'Analytics', 'GCP', 'Adhoc Analytics', 750),
(8, 'analytics-adhoc-2', 'Analytics', 'GCP', 'Adhoc Analytics', 950),
(9, 'ml-feature-build', 'ML', 'Azure', 'Feature Engineering', 1100),
(10, 'sandbox-experiment', 'Development', 'AWS', 'Experimentation', 200);

-- Find non-production clusters whose daily cost is greater than at least one production cluster
SELECT
    cluster_name,
    environment,
    workload_type,
    daily_cost
FROM cluster_costs
WHERE environment <> 'Production'
  AND daily_cost > ANY (
      SELECT daily_cost
      FROM cluster_costs
      WHERE environment = 'Production'
  );

-- Find non-production clusters whose daily cost is greater than all production clusters
SELECT
    cluster_name,
    environment,
    workload_type,
    daily_cost
FROM cluster_costs
WHERE environment <> 'Production'
  AND daily_cost > ALL (
      SELECT daily_cost
      FROM cluster_costs
      WHERE environment = 'Production'
  );


---------------------------

-- Union and Union ALL 

CREATE TABLE website_leads (
    lead_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    city VARCHAR(50)
);

CREATE TABLE app_leads (
    lead_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    city VARCHAR(50)
);

INSERT INTO website_leads
(lead_id, customer_name, email, city)
VALUES
(1, 'Amit Sharma', 'amit@example.com', 'Delhi'),
(2, 'Priya Mehta', 'priya@example.com', 'Mumbai'),
(3, 'Rahul Verma', 'rahul@example.com', 'Bangalore'),
(4, 'Sneha Kapoor', 'sneha@example.com', 'Pune');

INSERT INTO app_leads
(lead_id, customer_name, email, city)
VALUES
(101, 'Priya Mehta', 'priya@example.com', 'Mumbai'),
(102, 'Karan Singh', 'karan@example.com', 'Delhi'),
(103, 'Rahul Verma', 'rahul@example.com', 'Bangalore'),
(104, 'Neha Gupta', 'neha@example.com', 'Hyderabad');

-- Get a unique list of all leads from website and app.
SELECT
    customer_name,
    email,
    city
FROM website_leads

UNION

SELECT
    customer_name,
    email,
    city
FROM app_leads;

-- Get all leads from website and app, including duplicates.
SELECT
    customer_name,
    email,
    city
FROM website_leads

UNION ALL

SELECT
    customer_name,
    email,
    city
FROM app_leads;

-- Uber SQL Question
CREATE TABLE matches (
    id INT PRIMARY KEY,
    team_1 VARCHAR(100),
    team_2 VARCHAR(100),
    winner VARCHAR(100)
);

INSERT INTO matches
(id, team_1, team_2, winner)
VALUES
(1, 'India', 'Australia', 'India'),
(2, 'England', 'Sri Lanka', 'Sri Lanka'),
(3, 'New Zealand', 'India', 'New Zealand'),
(4, 'India', 'Sri Lanka', 'India'),
(5, 'England', 'India', 'India'),
(6, 'South Africa', 'West Indies', 'South Africa'),
(7, 'Australia', 'England', 'Australia'),
(8, 'West Indies', 'India', 'India'),
(9, 'South Africa', 'New Zealand', 'South Africa'),
(10, 'Australia', 'Sri Lanka', 'Australia'),
(11, 'West Indies', 'England', 'West Indies'),
(12, 'New Zealand', 'Sri Lanka', 'New Zealand');

-- Given a matches table with team_1, team_2, and winner, generate the full points table with columns like team, played, won, lost, points
SELECT
    team,
    COUNT(*) AS played,
    SUM(CASE WHEN result = 'Won' THEN 1 ELSE 0 END) AS won,
    SUM(CASE WHEN result = 'Lost' THEN 1 ELSE 0 END) AS lost,
    SUM(CASE WHEN result = 'Won' THEN 2 ELSE 0 END) AS points
FROM
(
    SELECT
        team_1 AS team,
        CASE
            WHEN team_1 = winner THEN 'Won'
            ELSE 'Lost'
        END AS result
    FROM matches

    UNION ALL

    SELECT
        team_2 AS team,
        CASE
            WHEN team_2 = winner THEN 'Won'
            ELSE 'Lost'
        END AS result
    FROM matches
) AS match_results
GROUP BY team
ORDER BY points DESC, won DESC, team;


-- Window Function

CREATE TABLE sales_orders (
    order_id INT PRIMARY KEY,
    sales_rep VARCHAR(100),
    region VARCHAR(50),
    order_date DATE,
    product_category VARCHAR(50),
    order_amount DECIMAL(10,2)
);

INSERT INTO sales_orders
(order_id, sales_rep, region, order_date, product_category, order_amount)
VALUES
(1, 'Amit', 'North', '2026-06-01', 'Laptop', 90000),
(2, 'Priya', 'West', '2026-06-01', 'Mobile', 60000),
(3, 'Rahul', 'North', '2026-06-02', 'Tablet', 30000),
(4, 'Sneha', 'South', '2026-06-02', 'Laptop', 85000),
(5, 'Amit', 'North', '2026-06-03', 'Mobile', 55000),
(6, 'Priya', 'West', '2026-06-03', 'Laptop', 95000),
(7, 'Rahul', 'North', '2026-06-04', 'Mobile', 50000),
(8, 'Sneha', 'South', '2026-06-04', 'Tablet', 35000),
(9, 'Karan', 'West', '2026-06-05', 'Laptop', 95000),
(10, 'Neha', 'South', '2026-06-05', 'Mobile', 58000),
(11, 'Amit', 'North', '2026-06-06', 'Laptop', 100000),
(12, 'Priya', 'West', '2026-06-06', 'Tablet', 40000),
(13, 'Rahul', 'North', '2026-06-07', 'Laptop', 75000),
(14, 'Sneha', 'South', '2026-06-07', 'Mobile', 62000),
(15, 'Karan', 'West', '2026-06-08', 'Mobile', 58000),
(16, 'Neha', 'South', '2026-06-08', 'Laptop', 90000),
(17, 'Amit', 'North', '2026-06-09', 'Tablet', 45000),
(18, 'Priya', 'West', '2026-06-09', 'Mobile', 70000),
(19, 'Karan', 'West', '2026-06-10', 'Tablet', 38000),
(20, 'Neha', 'South', '2026-06-10', 'Tablet', 42000);

-- For each region level we will get total sum
SELECT 
    *,
    SUM(order_amount) OVER(PARTITION BY region) as region_level_amount
FROM sales_orders;

-- Running SUM in each region

SELECT 
    *,
    SUM(order_amount) OVER(PARTITION BY region ORDER BY order_date) as region_level_amount
FROM sales_orders;


-- Running sum on full table
SELECT 
    *,
    SUM(order_amount) OVER(ORDER BY order_date) as running_sum
FROM sales_orders;

-- Find the highest-value order from each region, If two orders have the same order_amount, pick the one with the latest order_date. If there is still a tie, pick the higher order_id.
SELECT
    region,
    order_id,
    sales_rep,
    order_date,
    product_category,
    order_amount
FROM (
    SELECT
        order_id,
        sales_rep,
        region,
        order_date,
        product_category,
        order_amount,
        ROW_NUMBER() OVER (
            PARTITION BY region
            ORDER BY order_amount DESC, order_date DESC, order_id DESC
        ) AS rn
    FROM sales_orders
) t
WHERE rn = 1;

-- rank and dense rank
SELECT
    region,
    order_id,
    sales_rep,
    order_amount,

    RANK() OVER (
        PARTITION BY region
        ORDER BY order_amount DESC
    ) AS rank_position,

    DENSE_RANK() OVER (
        PARTITION BY region
        ORDER BY order_amount DESC
    ) AS dense_rank_position

FROM sales_orders
ORDER BY region, order_amount DESC, order_id;

-- LAG
-- The product team wants to identify products whose revenue is declining. A product should be flagged if its revenue dropped compared to the previous month.
CREATE TABLE product_monthly_revenue (
    revenue_id INT PRIMARY KEY,
    product_id INT,
    product_name VARCHAR(100),
    revenue_month DATE,
    revenue DECIMAL(10,2)
);

INSERT INTO product_monthly_revenue
(revenue_id, product_id, product_name, revenue_month, revenue)
VALUES
(1, 101, 'Wireless Mouse', '2026-01-01', 120000),
(2, 101, 'Wireless Mouse', '2026-02-01', 150000),
(3, 101, 'Wireless Mouse', '2026-03-01', 135000),
(4, 101, 'Wireless Mouse', '2026-04-01', 180000),
(5, 102, 'Mechanical Keyboard', '2026-01-01', 200000),
(6, 102, 'Mechanical Keyboard', '2026-02-01', 220000),
(7, 102, 'Mechanical Keyboard', '2026-03-01', 260000),
(8, 102, 'Mechanical Keyboard', '2026-04-01', 240000),
(9, 103, 'Laptop Stand', '2026-01-01', 90000),
(10, 103, 'Laptop Stand', '2026-02-01', 95000),
(11, 103, 'Laptop Stand', '2026-03-01', 130000),
(12, 103, 'Laptop Stand', '2026-04-01', 170000);

SELECT
    product_id,
    product_name,
    revenue_month,
    revenue AS current_month_revenue,
    previous_month_revenue,
    revenue - previous_month_revenue AS revenue_difference,
    CASE
        WHEN previous_month_revenue = 0 THEN 'First Month'
        WHEN revenue > previous_month_revenue THEN 'Growth'
        WHEN revenue < previous_month_revenue THEN 'Drop'
        ELSE 'No Change'
    END AS performance_flag
FROM (
    SELECT
        product_id,
        product_name,
        revenue_month,
        revenue,
        lag(revenue,1,0) OVER (
            PARTITION BY product_id
            ORDER BY revenue_month
        ) AS previous_month_revenue
    FROM product_monthly_revenue
) t
ORDER BY product_id, revenue_month;


-- LEAD
-- The growth team wants to detect possible churn risk. A user is considered at risk if, after one login, their next login happens after more than 7 days.
CREATE TABLE user_logins (
    login_id INT PRIMARY KEY,
    user_id INT,
    user_name VARCHAR(100),
    login_date DATE
);

INSERT INTO user_logins
(login_id, user_id, user_name, login_date)
VALUES
(1, 201, 'Amit', '2026-06-01'),
(2, 201, 'Amit', '2026-06-03'),
(3, 201, 'Amit', '2026-06-15'),
(4, 201, 'Amit', '2026-06-18'),
(5, 202, 'Priya', '2026-06-01'),
(6, 202, 'Priya', '2026-06-05'),
(7, 202, 'Priya', '2026-06-09'),
(8, 203, 'Rahul', '2026-06-02'),
(9, 203, 'Rahul', '2026-06-12'),
(10, 203, 'Rahul', '2026-06-25'),
(11, 204, 'Sneha', '2026-06-04'),
(12, 204, 'Sneha', '2026-06-06');

SELECT
    user_id,
    user_name,
    login_date,
    next_login_date,
    DATEDIFF(next_login_date, login_date) AS days_until_next_login
FROM (
    SELECT
        user_id,
        user_name,
        login_date,
        LEAD(login_date) OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS next_login_date
    FROM user_logins
) t
WHERE next_login_date IS NOT NULL
  AND DATEDIFF(next_login_date, login_date) > 7
ORDER BY user_id, login_date;


-- NTILE
-- The growth team wants to divide customers into 4 revenue segments based on their total purchase amount


CREATE TABLE customer_orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    customer_name VARCHAR(100),
    order_amount DECIMAL(10,2),
    order_date DATE
);

INSERT INTO customer_orders
(order_id, customer_id, customer_name, order_amount, order_date)
VALUES
(1, 101, 'Amit', 1200, '2026-06-01'),
(2, 101, 'Amit', 1800, '2026-06-05'),
(3, 102, 'Priya', 5000, '2026-06-02'),
(4, 102, 'Priya', 3000, '2026-06-08'),
(5, 103, 'Rahul', 2200, '2026-06-03'),
(6, 103, 'Rahul', 2800, '2026-06-10'),
(7, 104, 'Sneha', 9000, '2026-06-01'),
(8, 105, 'Karan', 1500, '2026-06-04'),
(9, 106, 'Neha', 6500, '2026-06-06'),
(10, 106, 'Neha', 2500, '2026-06-12'),
(11, 107, 'Rohit', 700, '2026-06-07'),
(12, 108, 'Anjali', 4000, '2026-06-03'),
(13, 108, 'Anjali', 3500, '2026-06-09'),
(14, 109, 'Vikas', 1100, '2026-06-11'),
(15, 110, 'Pooja', 10000, '2026-06-05');

SELECT
    customer_id,
    customer_name,
    total_revenue,
    NTILE(4) OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_bucket
FROM (
    SELECT
        customer_id,
        customer_name,
        SUM(order_amount) AS total_revenue
    FROM customer_orders
    GROUP BY customer_id, customer_name
) customer_revenue;

-- FRAME Caluse
CREATE TABLE daily_stock_prices (
    price_id INT PRIMARY KEY,
    stock_symbol VARCHAR(20),
    price_date DATE,
    closing_price DECIMAL(10,2)
);

INSERT INTO daily_stock_prices
(price_id, stock_symbol, price_date, closing_price)
VALUES
(1, 'TCS', '2026-06-01', 3800),
(2, 'TCS', '2026-06-02', 3850),
(3, 'TCS', '2026-06-03', 3820),
(4, 'TCS', '2026-06-04', 3900),
(5, 'TCS', '2026-06-05', 3950),
(6, 'TCS', '2026-06-06', 3920),
(7, 'TCS', '2026-06-07', 4000),

(8, 'INFY', '2026-06-01', 1500),
(9, 'INFY', '2026-06-02', 1520),
(10, 'INFY', '2026-06-03', 1510),
(11, 'INFY', '2026-06-04', 1540),
(12, 'INFY', '2026-06-05', 1560),
(13, 'INFY', '2026-06-06', 1550),
(14, 'INFY', '2026-06-07', 1580);

-- For each stock, calculate cumulative closing price day by day.
SELECT
    stock_symbol,
    price_date,
    closing_price,
    SUM(closing_price) OVER (
        PARTITION BY stock_symbol
        ORDER BY price_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_sum
FROM daily_stock_prices
ORDER BY stock_symbol, price_date;

-- Calculate a 3-day moving average closing price for each stock.
SELECT
    stock_symbol,
    price_date,
    closing_price,
    ROUND(
        AVG(closing_price) OVER (
            PARTITION BY stock_symbol
            ORDER BY price_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_avg_3_days
FROM daily_stock_prices
ORDER BY stock_symbol, price_date;

-- Calculate the average closing price for the current day and next 2 trading days.
SELECT
    stock_symbol,
    price_date,
    closing_price,
    ROUND(
        AVG(closing_price) OVER (
            PARTITION BY stock_symbol
            ORDER BY price_date
            ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING
        ),
        2
    ) AS next_3_day_avg
FROM daily_stock_prices
ORDER BY stock_symbol, price_date;

-- Calculate a centered 3-day average: previous day, current day, and next day.
SELECT
    stock_symbol,
    price_date,
    closing_price,
    ROUND(
        AVG(closing_price) OVER (
            PARTITION BY stock_symbol
            ORDER BY price_date
            ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
        ),
        2
    ) AS centered_3_day_avg
FROM daily_stock_prices
ORDER BY stock_symbol, price_date;

-- These two queries will retrun same result, region level total sum for each row
select 
   *,
   sum(closing_price) over(partition by stock_symbol) as stock_level_sum
from daily_stock_prices;

select 
   *,
   sum(closing_price) over(partition by stock_symbol 
   order by price_date rows between unbounded preceding and unbounded following) as total_sum
from daily_stock_prices;


-- Range Between
CREATE TABLE daily_sales (
    sale_id INT PRIMARY KEY,
    sales_date DATE,
    sales_amount DECIMAL(10,2)
);

INSERT INTO daily_sales
(sale_id, sales_date, sales_amount)
VALUES
(1, '2026-06-01', 1000),
(2, '2026-06-02', 1500),
(3, '2026-06-03', 1200),
(4, '2026-06-05', 2000),
(5, '2026-06-06', 1800),
(6, '2026-06-10', 2500),
(7, '2026-06-11', 2200),
(8, '2026-06-12', 1700),
(9, '2026-06-15', 3000),
(10, '2026-06-16', 2800);

-- Example
select 
   *,
   sum(sales_amount) over(order by sales_amount 
                    range between 300 preceding and 200 following) as total_sum
from daily_sales;

-- Find weekly running sum
select *,
       sum(sales_amount) over(order by sales_date range between interval '6' day preceding and current row) as running_weekly_sum
from daily_sales;

-- First_Value and Last_Value Window Function

CREATE TABLE employee_salary_history (
    record_id INT PRIMARY KEY,
    employee_id INT,
    employee_name VARCHAR(100),
    salary_date DATE,
    salary INT
);

INSERT INTO employee_salary_history
(record_id, employee_id, employee_name, salary_date, salary)
VALUES
(1, 101, 'Amit', '2023-01-01', 60000),
(2, 101, 'Amit', '2024-01-01', 75000),
(3, 101, 'Amit', '2025-01-01', 90000),
(4, 101, 'Amit', '2026-01-01', 110000),

(5, 102, 'Priya', '2023-01-01', 70000),
(6, 102, 'Priya', '2024-01-01', 85000),
(7, 102, 'Priya', '2025-01-01', 95000),
(8, 102, 'Priya', '2026-01-01', 120000),

(9, 103, 'Rahul', '2023-01-01', 50000),
(10, 103, 'Rahul', '2024-01-01', 65000),
(11, 103, 'Rahul', '2025-01-01', 72000),
(12, 103, 'Rahul', '2026-01-01', 80000);

-- For every employee salary record, show the employee’s first salary.
SELECT
    employee_id,
    employee_name,
    salary_date,
    salary,
    FIRST_VALUE(salary) OVER (
        PARTITION BY employee_id
        ORDER BY salary_date
    ) AS first_salary
FROM employee_salary_history
ORDER BY employee_id, salary_date;

-- For every employee salary record, show the employee’s latest salary.
SELECT
    employee_id,
    employee_name,
    salary_date,
    salary,
    LAST_VALUE(salary) OVER (
        PARTITION BY employee_id
        ORDER BY salary_date
    ) AS last_salary
FROM employee_salary_history
ORDER BY employee_id, salary_date;

-- Above doesn't give right answer due to bug, default frame is RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

-- Correct Query

SELECT
    employee_id,
    employee_name,
    salary_date,
    salary,
    LAST_VALUE(salary) OVER (
        PARTITION BY employee_id
        ORDER BY salary_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS latest_salary,

FROM employee_salary_history
ORDER BY employee_id, salary_date;

--- Iterative CTE

CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    employee_name VARCHAR(100),
    department VARCHAR(50),
    salary INT,
    performance_rating INT
);

INSERT INTO employees
(employee_id, employee_name, department, salary, performance_rating)
VALUES
(1, 'Amit', 'Engineering', 95000, 5),
(2, 'Priya', 'Engineering', 85000, 4),
(3, 'Rahul', 'Engineering', 70000, 3),
(4, 'Sneha', 'Engineering', 60000, 2),
(5, 'Karan', 'Data', 105000, 5),
(6, 'Neha', 'Data', 92000, 4),
(7, 'Rohit', 'Data', 76000, 3),
(8, 'Anjali', 'Data', 68000, 2),
(9, 'Vikas', 'Sales', 80000, 5),
(10, 'Pooja', 'Sales', 72000, 4),
(11, 'Nikhil', 'Sales', 62000, 3),
(12, 'Simran', 'Sales', 55000, 2);

-- Find employees whose salary is greater than the average salary of their department.
WITH department_avg_salary AS (
    SELECT
        department,
        AVG(salary) AS avg_department_salary
    FROM employees
    GROUP BY department
)
SELECT
    e.employee_id,
    e.employee_name,
    e.department,
    e.salary,
    ROUND(d.avg_department_salary, 2) AS avg_department_salary,
    ROUND(e.salary - d.avg_department_salary, 2) AS salary_difference
FROM employees e
INNER JOIN department_avg_salary d
    ON e.department = d.department and e.salary > d.avg_department_salary
ORDER BY e.department, salary_difference DESC;

-- Chaining of CTE's
CREATE TABLE payments (
    payment_id INT PRIMARY KEY,
    customer_id INT,
    customer_name VARCHAR(100),
    payment_date DATE,
    amount DECIMAL(10,2),
    payment_status VARCHAR(30)
);

INSERT INTO payments
(payment_id, customer_id, customer_name, payment_date, amount, payment_status)
VALUES
(1, 101, 'Amit', '2026-06-01', 1200, 'Success'),
(2, 101, 'Amit', '2026-06-05', 1500, 'Failed'),
(3, 101, 'Amit', '2026-06-08', 1800, 'Failed'),
(4, 101, 'Amit', '2026-06-12', 2000, 'Success'),
(5, 102, 'Priya', '2026-06-02', 2500, 'Success'),
(6, 102, 'Priya', '2026-06-06', 3000, 'Failed'),
(7, 102, 'Priya', '2026-06-10', 2800, 'Success'),
(8, 103, 'Rahul', '2026-06-01', 900, 'Failed'),
(9, 103, 'Rahul', '2026-06-04', 1100, 'Failed'),
(10, 103, 'Rahul', '2026-06-09', 1300, 'Failed'),
(11, 104, 'Sneha', '2026-06-03', 4000, 'Success'),
(12, 104, 'Sneha', '2026-06-07', 4200, 'Success');

-- The risk team wants to identify customers who had two consecutive failed payments.
WITH payment_sequence AS (
    SELECT
        payment_id,
        customer_id,
        customer_name,
        payment_date,
        amount,
        payment_status,
        LAG(payment_status) OVER (
            PARTITION BY customer_id
            ORDER BY payment_date
        ) AS previous_payment_status
    FROM payments
),

failed_payment_pairs AS (
    SELECT
        payment_id,
        customer_id,
        customer_name,
        payment_date,
        amount,
        payment_status,
        previous_payment_status
    FROM payment_sequence
    WHERE payment_status = 'Failed'
      AND previous_payment_status = 'Failed'
)

SELECT
    customer_id,
    customer_name,
    payment_id,
    payment_date,
    payment_status,
    previous_payment_status
FROM failed_payment_pairs
ORDER BY customer_id, payment_date;


--- Write a Query to generate numbers from 1 to 10 in SQL
--- Recurisve CTE

with recursive generate_numbers as   
(
  select 1 as n
  union 
  select n+1 from generate_numbers where n<10
) 

select * from generate_numbers;

create table emp_mgr
(
id int,
name varchar(50),
manager_id int,
designation varchar(50),
primary key (id)
);


insert into emp_mgr values(1,'Shripath',null,'CEO');
insert into emp_mgr values(2,'Satya',5,'SDE');
insert into emp_mgr values(3,'Jia',5,'DA');
insert into emp_mgr values(4,'David',5,'DS');
insert into emp_mgr values(5,'Michael',7,'Manager');
insert into emp_mgr values(6,'Arvind',7,'Architect');
insert into emp_mgr values(7,'Asha',1,'CTO');
insert into emp_mgr values(8,'Maryam',1,'Manager');


select * from emp_mgr;

--- For our CTO 'Asha', present her org chart

with recursive emp_hir as  
(
   select id, name, manager_id, designation from emp_mgr where name='Asha'
   UNION
   select em.id, em.name, em.manager_id, em.designation from emp_hir eh inner join emp_mgr em on eh.id = em.manager_id
)

select * from emp_hir;

--- Print level of employees as well
with recursive emp_hir as  
(
   select id, name, manager_id, designation, 1 as lvl from emp_mgr where name='Asha'
   UNION
   select em.id, em.name, em.manager_id, em.designation, eh.lvl + 1 as lvl from emp_hir eh inner join emp_mgr em on eh.id = em.manager_id
)

select * from emp_hir;

-- VIEWS in MySQL

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    customer_type VARCHAR(20)
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    order_amount DECIMAL(10,2),
    order_status VARCHAR(30),
    payment_mode VARCHAR(30)
);

INSERT INTO customers VALUES
(101, 'Amit Sharma', 'Delhi', 'Premium'),
(102, 'Priya Mehta', 'Mumbai', 'Regular'),
(103, 'Rahul Verma', 'Bangalore', 'Premium'),
(104, 'Sneha Rao', 'Delhi', 'Regular');

INSERT INTO orders VALUES
(1, 101, '2026-06-01', 1200, 'Delivered', 'UPI'),
(2, 101, '2026-06-05', 800, 'Delivered', 'Card'),
(3, 102, '2026-06-07', 1500, 'Cancelled', 'UPI'),
(4, 103, '2026-06-10', 2200, 'Delivered', 'Card'),
(5, 104, '2026-06-12', 700, 'Delivered', 'Cash');

CREATE VIEW vw_delivered_orders AS
SELECT
    o.order_id,
    o.order_date,
    c.customer_name,
    c.city,
    c.customer_type,
    o.order_amount,
    o.payment_mode
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered';


-- UDF in MySQL
CREATE TABLE delivery_orders (
    order_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    promised_minutes INT,
    actual_minutes INT,
    order_amount DECIMAL(10,2)
);

INSERT INTO delivery_orders
(order_id, customer_name, city, promised_minutes, actual_minutes, order_amount)
VALUES
(1, 'Amit', 'Delhi', 30, 28, 450),
(2, 'Priya', 'Mumbai', 35, 45, 800),
(3, 'Rahul', 'Delhi', 40, 55, 650),
(4, 'Sneha', 'Bangalore', 45, 42, 1200),
(5, 'Karan', 'Delhi', 30, 70, 700),
(6, 'Neha', 'Mumbai', 30, 38, 500);

DELIMITER $$

CREATE FUNCTION calculate_delivery_penalty(
    promised_minutes INT,
    actual_minutes INT
)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE delay_minutes INT;
    DECLARE penalty INT;

    SET delay_minutes = actual_minutes - promised_minutes;

    IF delay_minutes <= 0 THEN
        SET penalty = 0;
    ELSEIF delay_minutes <= 10 THEN
        SET penalty = 50;
    ELSEIF delay_minutes <= 30 THEN
        SET penalty = 100;
    ELSE
        SET penalty = 200;
    END IF;

    RETURN penalty;
END$$

DELIMITER ;


SELECT
    order_id,
    customer_name,
    city,
    promised_minutes,
    actual_minutes,
    actual_minutes - promised_minutes AS delay_minutes,
    calculate_delivery_penalty(promised_minutes, actual_minutes) AS penalty_amount
FROM delivery_orders;

--- Creat indexing
CREATE INDEX idx_order_id ON orders(order_id);

