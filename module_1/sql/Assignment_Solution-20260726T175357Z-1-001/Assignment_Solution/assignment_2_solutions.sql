-- ================================================================================
--                    SQL MASTERY BOOTCAMP - ASSIGNMENT 2 SOLUTIONS
-- ================================================================================

-- QUESTION 1: Products Never Ordered
-- Concept: LEFT JOIN with NULL check (Anti-Join pattern)
-- ================================================================================

-- Solution 1: Using LEFT JOIN
SELECT p.product_id, p.product_name, p.price
FROM assignment_sql.products_q1 p
LEFT JOIN assignment_sql.order_items_q1 oi ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL
ORDER BY p.product_id;

-- Solution 2: Using NOT EXISTS
SELECT p.product_id, p.product_name, p.price
FROM assignment_sql.products_q1 p
WHERE NOT EXISTS (
    SELECT 1 
    FROM assignment_sql.order_items_q1 oi 
    WHERE oi.product_id = p.product_id
)
ORDER BY p.product_id;

-- Explanation:
-- LEFT JOIN keeps all products, NULL in oi means never ordered
-- NOT EXISTS is often more efficient for large datasets
-- Both achieve the anti-join pattern

-- ================================================================================
-- QUESTION 2: Customers with Orders Above Average
-- Concept: Subquery in HAVING clause
-- ================================================================================

WITH customer_totals AS (
    SELECT 
        c.customer_name,
        SUM(o.order_amount) AS total_amount
    FROM assignment_sql.customers_q2 c
    JOIN assignment_sql.orders_q2 o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.customer_name
)
SELECT customer_name, total_amount
FROM customer_totals
WHERE total_amount > (SELECT AVG(total_amount) FROM customer_totals)
ORDER BY total_amount;

-- Explanation:
-- First calculate total per customer
-- Then compare to average of those totals
-- Subquery in WHERE filters customers above average

-- ================================================================================
-- QUESTION 3: Employees with Manager's Salary
-- Concept: Self-join for hierarchical comparison
-- ================================================================================

SELECT 
    e.emp_name,
    e.salary AS emp_salary,
    m.emp_name AS manager_name,
    m.salary AS manager_salary
FROM assignment_sql.emp_mgr e
JOIN assignment_sql.emp_mgr m ON e.manager_id = m.emp_id
WHERE e.salary > m.salary;

-- Explanation:
-- Self-join links employee to their manager
-- e.manager_id = m.emp_id connects employee to manager row
-- Filter where employee salary exceeds manager salary

-- ================================================================================
-- QUESTION 4: Department with Highest Average Salary
-- Concept: Subquery with aggregate function
-- ================================================================================

SELECT 
    department,
    ROUND(AVG(salary), 2) AS avg_salary
FROM assignment_sql.dept_emp
GROUP BY department
HAVING AVG(salary) = (
    SELECT MAX(dept_avg)
    FROM (
        SELECT AVG(salary) AS dept_avg
        FROM assignment_sql.dept_emp
        GROUP BY department
    ) AS dept_averages
);

-- Alternative using ORDER BY LIMIT:
SELECT 
    department,
    ROUND(AVG(salary), 2) AS avg_salary
FROM assignment_sql.dept_emp
GROUP BY department
ORDER BY avg_salary DESC
LIMIT 1;

-- Explanation:
-- Nested subquery finds the maximum average
-- HAVING filters to department matching that maximum
-- LIMIT 1 approach is simpler but may miss ties

-- ================================================================================
-- QUESTION 5: Correlated Subquery - Latest Order Per Customer
-- Concept: Correlated subquery for max per group
-- ================================================================================

SELECT order_id, customer_id, order_date, amount
FROM assignment_sql.cust_orders_q5 o
WHERE order_date = (
    SELECT MAX(order_date)
    FROM assignment_sql.cust_orders_q5
    WHERE customer_id = o.customer_id
)
ORDER BY customer_id;

-- Explanation:
-- Correlated subquery references outer query's customer_id
-- Finds max order_date for each customer
-- Outer query filters to rows matching that max date

-- ================================================================================
-- QUESTION 6: Complete Sales Analysis
-- Concept: Combine LEFT JOIN with unmatched rows from the right table
-- ================================================================================

SELECT 
    p.product_id,
    p.product_name,
    s.sale_id,
    s.quantity
FROM assignment_sql.products_q6 p
LEFT JOIN assignment_sql.sales_q6 s ON p.product_id = s.product_id

UNION ALL

SELECT
    s.product_id,
    NULL AS product_name,
    s.sale_id,
    s.quantity
FROM assignment_sql.sales_q6 s
LEFT JOIN assignment_sql.products_q6 p ON p.product_id = s.product_id
WHERE p.product_id IS NULL
ORDER BY product_id, sale_id;

-- Explanation:
-- UNION ALL combines products with sales plus sales with no matching product
-- Products with no sales show NULL for sale columns
-- Sales with invalid product_id show NULL for product columns
-- COALESCE handles NULL in ordering

-- ================================================================================
-- QUESTION 7: EXISTS vs IN - Find Active Customers
-- Concept: Both approaches for same result
-- ================================================================================

-- Solution using EXISTS:
SELECT c.customer_id, c.customer_name, c.email
FROM assignment_sql.customers_q7 c
WHERE EXISTS (
	    SELECT 1
	    FROM assignment_sql.orders_q7 o
	    WHERE o.customer_id = c.customer_id
	      AND o.order_date >= DATE_SUB('2024-01-30', INTERVAL 30 DAY)
	)
ORDER BY c.customer_id;

-- Solution using IN:
SELECT customer_id, customer_name, email
FROM assignment_sql.customers_q7
WHERE customer_id IN (
	SELECT customer_id
	FROM assignment_sql.orders_q7
	WHERE order_date >= DATE_SUB('2024-01-30', INTERVAL 30 DAY)
)
ORDER BY customer_id;

-- Explanation:
-- EXISTS stops at first match (can be faster for large datasets)
-- IN creates a list of all matching values first
-- Both give same results, EXISTS often preferred for performance

-- ================================================================================
-- QUESTION 8: Multiple Table Join with Aggregation
-- Concept: Joining 3 tables with GROUP BY
-- ================================================================================

SELECT 
    c.category_name,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * p.price) AS total_sales
FROM assignment_sql.categories_q8 c
JOIN assignment_sql.products_q8 p ON c.category_id = p.category_id
JOIN assignment_sql.order_items_q8 oi ON p.product_id = oi.product_id
GROUP BY c.category_id, c.category_name
ORDER BY total_sales DESC;

-- Explanation:
-- Chain joins from category through product to order items
-- Calculate quantity and revenue per category
-- GROUP BY category for aggregation

-- ================================================================================
-- QUESTION 9: Scalar Subquery in SELECT
-- Concept: Subquery returning single value in SELECT
-- ================================================================================

SELECT 
    emp_name,
    department,
    salary,
    (SELECT ROUND(AVG(salary), 0) FROM assignment_sql.emp_scalar) AS company_avg,
    salary - (SELECT ROUND(AVG(salary), 0) FROM assignment_sql.emp_scalar) AS diff_from_avg
FROM assignment_sql.emp_scalar
ORDER BY salary DESC;

-- Explanation:
-- Scalar subquery returns single value (company average)
-- Executes once for entire query, not per row
-- Subtraction shows difference from average

-- ================================================================================
-- QUESTION 10: Anti-Join Pattern
-- Concept: Finding records with no matching records
-- ================================================================================

-- Solution using LEFT JOIN:
SELECT s.student_id, s.student_name
FROM assignment_sql.students_q10 s
LEFT JOIN assignment_sql.enrollments_q10 e ON s.student_id = e.student_id
WHERE e.enrollment_id IS NULL
ORDER BY s.student_id;

-- Solution using NOT EXISTS:
SELECT student_id, student_name
FROM assignment_sql.students_q10 s
WHERE NOT EXISTS (
    SELECT 1 
    FROM assignment_sql.enrollments_q10 e 
    WHERE e.student_id = s.student_id
)
ORDER BY student_id;

-- Explanation:
-- Anti-join finds records in one table without matches in another
-- LEFT JOIN with NULL check is intuitive
-- NOT EXISTS is often more performant

-- ================================================================================
-- QUESTION 11: Semi-Join Pattern
-- Concept: Finding records that have matching records
-- ================================================================================

-- Solution using EXISTS:
SELECT d.dept_id, d.dept_name
FROM assignment_sql.departments_q11 d
WHERE EXISTS (
    SELECT 1
    FROM assignment_sql.employees_q11 e
    WHERE e.dept_id = d.dept_id
      AND e.salary > 80000
)
ORDER BY d.dept_id;

-- Solution using IN:
SELECT dept_id, dept_name
FROM assignment_sql.departments_q11
WHERE dept_id IN (
    SELECT dept_id
    FROM assignment_sql.employees_q11
    WHERE salary > 80000
)
ORDER BY dept_id;

-- Explanation:
-- Semi-join checks existence without returning duplicate rows
-- EXISTS stops at first match, more efficient
-- IN works but may process all matches

-- ================================================================================
-- QUESTION 12: Cross Join - Generate Combinations
-- Concept: Cartesian product of two tables
-- ================================================================================

SELECT 
    p.product_name,
    c.color_name
FROM assignment_sql.products_q12 p
CROSS JOIN assignment_sql.colors_q12 c
ORDER BY p.product_name, c.color_name;

-- Explanation:
-- CROSS JOIN produces all possible combinations
-- 2 products × 3 colors = 6 rows
-- Useful for generating all permutations

-- ================================================================================
-- QUESTION 13: NOT EXISTS vs NOT IN
-- Concept: Handling NULLs in anti-patterns
-- ================================================================================

-- Solution using NOT EXISTS (NULL-safe):
SELECT emp_id, emp_name
FROM assignment_sql.employees_q13 e
WHERE NOT EXISTS (
    SELECT 1
    FROM assignment_sql.expenses_q13 ex
    WHERE ex.emp_id = e.emp_id
)
ORDER BY emp_id;

-- Solution using NOT IN (be careful with NULLs):
SELECT emp_id, emp_name
FROM assignment_sql.employees_q13
WHERE emp_id NOT IN (
    SELECT emp_id 
    FROM assignment_sql.expenses_q13
    WHERE emp_id IS NOT NULL  -- Important for NOT IN!
)
ORDER BY emp_id;

-- Explanation:
-- NOT EXISTS handles NULLs correctly
-- NOT IN returns no results if subquery contains NULL
-- Always prefer NOT EXISTS or add NULL filter

-- ================================================================================
-- QUESTION 14: Derived Table (Inline View)
-- Concept: Subquery in FROM clause
-- ================================================================================

SELECT 
    customer_id,
    first_order_amt
FROM (
    SELECT 
        customer_id,
        amount AS first_order_amt,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
    FROM assignment_sql.orders_q14
) AS first_orders
WHERE rn = 1 AND first_order_amt > 500
ORDER BY customer_id;

-- Explanation:
-- Inline view (derived table) creates temporary result set
-- ROW_NUMBER identifies first order per customer
-- Filter for first orders above 500

-- ================================================================================
-- QUESTION 15: GROUP BY with HAVING and Subquery
-- Concept: Subquery in HAVING clause
-- ================================================================================

SELECT 
    product_id,
    COUNT(*) AS order_count
FROM assignment_sql.order_items_q15
GROUP BY product_id
HAVING COUNT(*) > (
    SELECT AVG(cnt)
    FROM (
        SELECT COUNT(*) AS cnt
        FROM assignment_sql.order_items_q15
        GROUP BY product_id
    ) AS product_counts
)
ORDER BY order_count DESC;

-- Explanation:
-- Inner subquery calculates average order count per product
-- HAVING filters products with above-average order counts
-- Nested subquery provides aggregate of aggregates

-- ================================================================================
-- QUESTION 16: UNION vs UNION ALL
-- Concept: Removing duplicates with UNION
-- ================================================================================

-- UNION (removes duplicates):
SELECT customer_id, customer_name
FROM assignment_sql.customers_east
UNION
SELECT customer_id, customer_name
FROM assignment_sql.customers_west
ORDER BY customer_id;

-- UNION ALL (keeps all rows including duplicates):
SELECT customer_id, customer_name
FROM assignment_sql.customers_east
UNION ALL
SELECT customer_id, customer_name
FROM assignment_sql.customers_west
ORDER BY customer_id;

-- Explanation:
-- UNION removes duplicate rows (slower, sorts data)
-- UNION ALL keeps all rows (faster, no sorting)
-- Use UNION when deduplication needed

-- ================================================================================
-- QUESTION 17: Common Records
-- Concept: Finding common records in both tables
-- ================================================================================

SELECT DISTINCT product_id, product_name
FROM assignment_sql.online_products
WHERE (product_id, product_name) IN (
    SELECT product_id, product_name
    FROM assignment_sql.retail_products
)
ORDER BY product_id;

-- Explanation:
-- Tuple IN returns rows present in both result sets
-- Automatically removes duplicates
-- Column count and types must match

-- ================================================================================
-- QUESTION 18: Records in One Table But Not Another
-- Concept: Set difference operation
-- ================================================================================

SELECT DISTINCT emp_id, emp_name
FROM assignment_sql.payroll_employees
WHERE (emp_id, emp_name) NOT IN (
    SELECT emp_id, emp_name
    FROM assignment_sql.hr_employees
)
ORDER BY emp_id;

-- Explanation:
-- NOT IN returns rows in first set but not in second
-- Order matters: A minus B is not the same as B minus A
-- Also known as MINUS in some databases

-- ================================================================================
-- QUESTION 19: Self-Join - Find Pairs
-- Concept: Joining table to itself for pair matching
-- ================================================================================

SELECT 
    e1.emp_name AS employee_1,
    e2.emp_name AS employee_2,
    e1.department
FROM assignment_sql.emp_pairs_q19 e1
JOIN assignment_sql.emp_pairs_q19 e2 
    ON e1.department = e2.department 
    AND e1.emp_id < e2.emp_id
ORDER BY e1.department, e1.emp_name;

-- Explanation:
-- Self-join matches employees in same department
-- e1.emp_id < e2.emp_id prevents duplicates and self-pairs
-- Creates unique pairs only

-- ================================================================================
-- QUESTION 20: Nested Subquery in WHERE
-- Concept: Multiple levels of subquery nesting
-- ================================================================================

SELECT emp_id, emp_name, department, salary
FROM assignment_sql.emp_nested
WHERE salary > (
    SELECT MAX(salary)
    FROM assignment_sql.emp_nested
    WHERE department = 'Sales'
)
ORDER BY salary DESC;

-- Explanation:
-- Inner subquery finds max salary in Sales (75000)
-- Outer query finds all employees earning more
-- Simple comparison with scalar subquery

-- ================================================================================
-- QUESTION 21: Multiple Subqueries in SELECT
-- Concept: Correlated subqueries for conditional counts
-- ================================================================================

SELECT 
    department,
    COUNT(*) AS total_count,
    SUM(CASE WHEN salary > 60000 THEN 1 ELSE 0 END) AS above_60k_count
FROM assignment_sql.emp_counts
GROUP BY department
ORDER BY department;

-- Alternative with subqueries:
SELECT DISTINCT
    department,
    (SELECT COUNT(*) FROM assignment_sql.emp_counts e2 
     WHERE e2.department = e1.department) AS total_count,
    (SELECT COUNT(*) FROM assignment_sql.emp_counts e3 
     WHERE e3.department = e1.department AND e3.salary > 60000) AS above_60k_count
FROM assignment_sql.emp_counts e1
ORDER BY department;

-- Explanation:
-- CASE WHEN approach is more efficient
-- Subquery approach shows correlated subquery pattern
-- Both produce same result

-- ================================================================================
-- QUESTION 22: Conditional Aggregation
-- Concept: CASE WHEN inside aggregate functions
-- ================================================================================

SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN status = 'Pending' THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled
FROM assignment_sql.orders_status
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;

-- Explanation:
-- CASE WHEN converts status to 1/0
-- SUM counts occurrences of each status
-- Creates pivot-like output

-- ================================================================================
-- QUESTION 23: CASE WHEN in JOIN Condition
-- Concept: Simple join on rating column
-- ================================================================================

SELECT 
    e.emp_name,
    e.performance_rating,
    b.bonus_percentage
FROM assignment_sql.employees_bonus e
JOIN assignment_sql.bonus_rates b ON e.performance_rating = b.rating
ORDER BY b.bonus_percentage DESC, e.emp_name;

-- Explanation:
-- Direct join on rating column
-- Each employee gets their corresponding bonus rate
-- Simple equi-join pattern

-- ================================================================================
-- QUESTION 24: Subquery in FROM Clause (Derived Table)
-- Concept: Finding max from grouped data
-- ================================================================================

SELECT department, total_salary
FROM (
    SELECT 
        department,
        SUM(salary) AS total_salary
    FROM assignment_sql.dept_salary
    GROUP BY department
) AS dept_totals
ORDER BY total_salary DESC
LIMIT 1;

-- Alternative using CTE:
WITH dept_totals AS (
    SELECT 
        department,
        SUM(salary) AS total_salary
    FROM assignment_sql.dept_salary
    GROUP BY department
)
SELECT department, total_salary
FROM dept_totals
WHERE total_salary = (SELECT MAX(total_salary) FROM dept_totals);

-- Explanation:
-- Derived table aggregates salaries by department
-- LIMIT 1 or WHERE MAX() finds highest
-- CTE version handles ties

-- ================================================================================
-- QUESTION 25: Multiple Conditions with ANY/ALL
-- Concept: Comparison operators with subqueries
-- ================================================================================

SELECT product_id, product_name, category, price
FROM assignment_sql.products_any
WHERE price > ANY (
    SELECT price 
    FROM assignment_sql.products_any 
    WHERE category = 'Accessories'
)
ORDER BY price;

-- With ALL (price > ALL accessories = greater than max accessory):
SELECT product_id, product_name, category, price
FROM assignment_sql.products_any
WHERE price > ALL (
    SELECT price 
    FROM assignment_sql.products_any 
    WHERE category = 'Accessories'
);

-- Explanation:
-- ANY: greater than at least one value (> MIN)
-- ALL: greater than every value (> MAX)
-- Useful for set comparisons

-- ================================================================================
-- QUESTION 26: Conditional Aggregation
-- Concept: CASE WHEN inside aggregate functions
-- ================================================================================

SELECT 
    salesperson,
    SUM(CASE WHEN EXTRACT(QUARTER FROM sale_date) = 1 THEN amount ELSE 0 END) AS q1,
    SUM(CASE WHEN EXTRACT(QUARTER FROM sale_date) = 2 THEN amount ELSE 0 END) AS q2
FROM assignment_sql.sales_filter
GROUP BY salesperson
ORDER BY salesperson;

-- Alternative with CASE expressions:
SELECT 
    salesperson,
    SUM(CASE WHEN EXTRACT(QUARTER FROM sale_date) = 1 THEN amount ELSE 0 END) AS q1,
    SUM(CASE WHEN EXTRACT(QUARTER FROM sale_date) = 2 THEN amount ELSE 0 END) AS q2
FROM assignment_sql.sales_filter
GROUP BY salesperson
ORDER BY salesperson;

-- Explanation:
-- EXTRACT(QUARTER) gets quarter number from date
-- CASE WHEN creates conditional sums

-- ================================================================================
-- QUESTION 27: Top N Orders Per Customer
-- Concept: ROW_NUMBER() for top N rows per group
-- ================================================================================

WITH ranked_orders AS (
    SELECT
        o.*,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id
            ORDER BY o.amount DESC
        ) AS order_rank
    FROM assignment_sql.orders_lat o
)
SELECT 
    c.customer_name,
    ro.order_id,
    ro.amount
FROM assignment_sql.customers_lat c
JOIN ranked_orders ro
    ON ro.customer_id = c.customer_id
   AND ro.order_rank <= 2
ORDER BY c.customer_name, ro.amount DESC;

-- Explanation:
-- ROW_NUMBER ranks orders within each customer
-- Gets top 2 orders per customer efficiently

-- ================================================================================
-- QUESTION 28: Recursive Query - Generate Date Series
-- Concept: Recursive CTE for sequence generation
-- ================================================================================

WITH RECURSIVE date_series AS (
    -- Base case
    SELECT CAST('2024-01-01' AS DATE) AS date_value
    
    UNION ALL
    
    -- Recursive case
    SELECT DATE_ADD(date_value, INTERVAL 1 DAY)
    FROM date_series
    WHERE date_value < '2024-01-07'
)
SELECT date_value
FROM date_series
ORDER BY date_value;

-- Explanation:
-- Recursive CTE starts with base date
-- Each iteration adds one day until end date

-- ================================================================================
-- QUESTION 29: String Aggregation with GROUP BY
-- Concept: GROUP_CONCAT for concatenating strings
-- ================================================================================

SELECT 
    department,
    GROUP_CONCAT(emp_name ORDER BY emp_name SEPARATOR ', ') AS employee_names
FROM assignment_sql.emp_string_agg
GROUP BY department
ORDER BY department;

-- Explanation:
-- GROUP_CONCAT concatenates strings with delimiter
-- ORDER BY within GROUP_CONCAT controls ordering

-- ================================================================================
-- QUESTION 30: Complex Join with Multiple Conditions
-- Concept: Multi-table join with GROUP BY HAVING
-- ================================================================================

SELECT 
    c.customer_name,
    p.product_name,
    COUNT(DISTINCT o.order_id) AS times_ordered
FROM assignment_sql.customers_q30 c
JOIN assignment_sql.orders_q30 o ON c.customer_id = o.customer_id
JOIN assignment_sql.order_items_q30 oi ON o.order_id = oi.order_id
JOIN assignment_sql.products_q30 p ON oi.product_id = p.product_id
GROUP BY c.customer_id, c.customer_name, p.product_id, p.product_name
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER BY times_ordered DESC, c.customer_name;

-- Explanation:
-- Four-table join connects customers to their ordered products
-- COUNT(DISTINCT order_id) counts unique orders per product per customer
-- HAVING > 1 filters to products ordered multiple times
-- Identifies repeat purchases of same product

-- ================================================================================
--                              END OF SOLUTIONS
-- ================================================================================
