/*
    SQL Class 2 - Practical MySQL Commands
    --------------------------------------
    This script demonstrates common SQL concepts using practical business examples:
    1. Database and table creation
    2. ALTER TABLE operations
    3. Constraints: UNIQUE, PRIMARY KEY, FOREIGN KEY
    4. SELECT queries, aliases, DISTINCT, COUNT
    5. UPDATE and DELETE with WHERE
    6. AUTO_INCREMENT
    7. LIMIT, ORDER BY, filtering, BETWEEN, LIKE
*/

CREATE DATABASE IF NOT EXISTS data_eng_db;
USE data_eng_db;

-- =========================================================
-- 1. Basic table creation
-- =========================================================

/*
    employee_profile is a simple practice table.
    We will use it to learn ALTER TABLE commands such as:
    - ADD COLUMN
    - MODIFY COLUMN
    - DROP COLUMN
    - RENAME COLUMN
*/
CREATE TABLE IF NOT EXISTS employee_profile (
    id INT,
    name VARCHAR(50),
    address VARCHAR(100),
    city VARCHAR(50)
);

INSERT INTO employee_profile (id, name, address, city)
VALUES (1, 'Shashank', 'Address 1', 'Lucknow');

SELECT * FROM employee_profile;

-- Add a new column to store the employee date of birth.
ALTER TABLE employee_profile
ADD COLUMN dob DATE;

SELECT * FROM employee_profile;

-- Increase the name column length because real names can be longer than 50 characters.
ALTER TABLE employee_profile
MODIFY COLUMN name VARCHAR(100);

-- Show the create table statement for the employee_profile table.
SHOW CREATE TABLE employee_profile;

-- Remove city because address may already include city details in this example.
ALTER TABLE employee_profile
DROP COLUMN city;

SELECT * FROM employee_profile;

-- Rename name to full_name to make the column meaning more clear.
ALTER TABLE employee_profile
RENAME COLUMN name TO full_name;

SELECT * FROM employee_profile;

-- =========================================================
-- 2. Practical employee table
-- =========================================================

/*
    employees represents a small company employee dataset.
    This table will be used for constraints, SELECT, UPDATE, DELETE,
    sorting, filtering, and aggregate examples.
*/
CREATE TABLE IF NOT EXISTS employees (
    employee_id INT,
    full_name VARCHAR(100),
    age INT,
    hiring_date DATE,
    salary DECIMAL(10, 2),
    city VARCHAR(50),
    department VARCHAR(50)
);

INSERT INTO employees
    (employee_id, full_name, age, hiring_date, salary, city, department)
VALUES
    (1, 'Shashank Mishra', 24, '2021-08-10', 10000.00, 'Lucknow', 'Data Engineering'),
    (2, 'Rahul Sharma', 25, '2021-08-10', 20000.00, 'Khajuraho', 'Analytics'),
    (3, 'Sunny Verma', 22, '2021-08-11', 11000.00, 'Bangalore', 'Data Engineering'),
    (5, 'Amit Singh', 25, '2021-08-11', 12000.00, 'Noida', 'Operations'),
    (6, 'Puneet Yadav', 26, '2021-08-12', 50000.00, 'Gurgaon', 'Cloud Engineering'),
    (7, 'Akhil Singh', 27, '2021-08-13', 60000.00, 'Delhi', 'Data Engineering')
    (8, 'Rajesh Kumar', 28, '2021-08-14', 70000.00, 'Mumbai', 'Data Engineering'),
    (9, 'Vikash Yadav', 29, '2021-08-15', 80000.00, 'Chennai', 'Data Engineering'),
    (10, 'Deepak Singh', 30, '2021-08-16', 90000.00, 'Hyderabad', 'Cloud Engineering'),
    (11, 'Vikash Yadav', 31, '2021-08-17', 100000.00, 'Kolkata', 'Analytics'),
    (12, 'Priya Sharma', 32, '2021-08-18', 110000.00, 'Pune', 'Operations'),
    (13, 'Neha Yadav', 33, '2021-08-19', 120000.00, 'Jaipur', 'Cloud Engineering'),
    (14, 'Rakshita Kumar', 34, '2021-08-20', 130000.00, 'Ahmedabad', 'Data Engineering'),
    (15, 'Puja Mishra', 35, '2021-08-21', 140000.00, 'Surat', 'Operations');

SELECT * FROM employees;

-- =========================================================
-- 3. UNIQUE constraint
-- =========================================================

/*
    A UNIQUE constraint prevents duplicate values in a column.
    In a real employee table, employee_id should not repeat.
*/
ALTER TABLE employees
ADD CONSTRAINT uq_employees_employee_id UNIQUE (employee_id);

-- This insert will fail because employee_id = 1 already exists.
-- Uncomment during class to test the UNIQUE constraint.
INSERT INTO employees
    (employee_id, full_name, age, hiring_date, salary, city, department)
VALUES
    (1, 'Duplicate Employee', 25, '2021-08-10', 50000.00, 'Gurgaon', 'Testing');

-- Drop the UNIQUE constraint if you want to allow duplicate employee IDs again.
-- MySQL stores a UNIQUE constraint as a unique index.
ALTER TABLE employees
DROP CONSTRAINT uq_employees_employee_id;

-- This insert now works because the UNIQUE constraint has been removed.
INSERT INTO employees
    (employee_id, full_name, age, hiring_date, salary, city, department)
VALUES
    (1, 'Duplicate Employee Demo', 25, '2021-08-10', 50000.00, 'Gurgaon', 'Testing');

SELECT * FROM employees;

-- =========================================================
-- 4. PRIMARY KEY constraint
-- =========================================================

/*
    A PRIMARY KEY uniquely identifies each row.
    Important points:
    - It cannot contain duplicate values.
    - It cannot contain NULL values.
    - A table can have only one primary key.
*/
CREATE TABLE guests (
    guest_id INT,
    full_name VARCHAR(100),
    age INT,
    CONSTRAINT pk_guests PRIMARY KEY (guest_id)
);

INSERT INTO guests (guest_id, full_name, age)
VALUES (1, 'Shashank Mishra', 29);

-- This will fail because guest_id = 1 already exists.
INSERT INTO guests (guest_id, full_name, age)
VALUES (1, 'Rahul Sharma', 28);

-- This will fail because a primary key cannot be NULL.
INSERT INTO guests (guest_id, full_name, age)
VALUES (NULL, 'Amit Singh', 28);

SELECT * FROM guests;

-- =========================================================
-- 5. FOREIGN KEY constraint
-- =========================================================

/*
    A FOREIGN KEY connects rows between two tables.
    Example:
    - customers contains customer details.
    - orders contains order details.
    - orders.customer_id must exist in customers.customer_id.
*/
CREATE TABLE customers (
    customer_id INT,
    full_name VARCHAR(100),
    age INT,
    city VARCHAR(50),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
);

CREATE TABLE orders (
    order_id INT,
    amount DECIMAL(10, 2),
    cust_id INT,
    order_date DATE,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer FOREIGN KEY (cust_id) REFERENCES customers(customer_id)
);

INSERT INTO customers (customer_id, full_name, age, city)
VALUES
    (1, 'Shashank Mishra', 29, 'Lucknow'),
    (2, 'Rahul Sharma', 30, 'Delhi');

SELECT * FROM customers;

INSERT INTO orders (order_id, amount, cust_id, order_date)
VALUES
    (1001, 2000.00, 1, '2024-05-01'),
    (1002, 3000.00, 2, '2024-05-02');

SELECT * FROM orders;

-- This will fail because customer_id = 5 does not exist in customers.
INSERT INTO orders (order_id, amount, cust_id, order_date)
VALUES (1004, 3500.00, 5, '2024-05-03');

-- =========================================================
-- 6. SELECT command basics
-- =========================================================

SELECT * FROM employees;

-- Count total rows in the table.
SELECT COUNT(*) AS total_employee_count
FROM employees;

-- Display specific columns only.
SELECT full_name, salary
FROM employees;

-- Use aliases to make result column names more readable.
SELECT
    full_name AS employee_name,
    salary AS employee_salary
FROM employees;

-- Show unique departments.
SELECT DISTINCT department
FROM employees;

-- Count unique departments in the table.
SELECT COUNT(DISTINCT department) AS total_unique_departments
FROM employees;

-- Calculate a 20% salary increment without changing the table data.
SELECT
    employee_id,
    full_name,
    salary AS old_salary,
    salary + (salary * 0.20) AS salary_after_20_percent_increment
FROM employees;

-- =========================================================
-- 7. WHERE clause with comparison and logical operators
-- =========================================================

-- Comparison operators: <, >, <=, >=, =, !=, <>
-- Logical operators: AND, OR, NOT

-- Employees earning more than 20000.
SELECT *
FROM employees
WHERE salary > 20000;

-- Employees earning more than or equal to 20000.
SELECT *
FROM employees
WHERE salary >= 20000;

-- Employees earning less than 20000.
SELECT *
FROM employees
WHERE salary < 20000;

-- Employees whose are working in the Data Engineering department.
SELECT *
FROM employees
WHERE department = 'Data Engineering';

-- Employees who are not working in the Data Engineering department.
SELECT *
FROM employees
WHERE department != 'Data Engineering';

SELECT *
FROM employees
WHERE department <> 'Data Engineering';

-- Employees who joined on 2021-08-11 and earn less than 15000.
SELECT *
FROM employees
WHERE hiring_date = '2021-08-11'
  AND salary < 15000;

-- Employees who are working in the Analytics or Cloud Engineering department.
SELECT *
FROM employees
WHERE department = 'Analytics' OR department = 'Cloud Engineering';

-- =========================================================
-- 8. BETWEEN operator
-- =========================================================

-- Employees who joined between two dates. BETWEEN includes both boundary values.
SELECT *
FROM employees
WHERE hiring_date BETWEEN '2021-08-05' AND '2021-08-11';

-- Employees with salary between 10000 and 28000.
SELECT *
FROM employees
WHERE salary BETWEEN 10000 AND 50000;

-- =========================================================
-- 9. UPDATE command
-- =========================================================

/*
    Be careful with UPDATE.
    Without WHERE, every row in the table will be updated.
*/
SELECT * FROM employees;

-- Example of updating all rows: set default age to 20.
-- Keep this commented because it is usually not what we want in real work.
-- UPDATE employees SET age = 20;

-- Give every employee a 20% salary increment.
UPDATE employees
SET salary = salary + (salary * 0.20);

-- Update departments of employees who are working in the Data Engineering department to Data Platform.
UPDATE employees
SET department = 'Data Platform' 
WHERE department = 'Data Engineering';

-- Update multiple columns for one employee only. Salary to 50000 and department to Cloud Engineering.
UPDATE employees 
SET salary = 50000, department = 'Cloud Engineering' WHERE employee_id = 1;


SELECT * FROM employees;

-- =========================================================
-- 10. DELETE command
-- =========================================================

/*
    DELETE removes rows from a table.
    Always check the rows with SELECT before running DELETE.
*/
DELETE FROM employees where full_name = 'Amit Mishra';

SELECT * FROM employees;

-- =========================================================
-- 11. DROP vs TRUNCATE
-- =========================================================

/*
    DELETE   -> removes selected rows and can use WHERE.
    TRUNCATE -> removes all rows quickly but keeps the table structure.
    DROP     -> removes the complete table structure and data.
*/

SELECT * FROM guests;

TRUNCATE TABLE guests;

-- guests still exists, but it has no rows now.
SELECT * FROM guests;

DROP TABLE guests;

-- This would fail because the table was dropped.
-- SELECT * FROM guests;

-- =========================================================
-- 12. AUTO_INCREMENT
-- =========================================================

/*
    AUTO_INCREMENT is useful for automatically generating IDs.
    It is commonly used for primary key columns.
*/
CREATE TABLE auto_inc_example (
    id INT AUTO_INCREMENT,
    full_name VARCHAR(100),
    PRIMARY KEY (id)
);

INSERT INTO auto_inc_example (full_name)
VALUES
    ('Shashank Mishra'),
    ('Rahul Sharma');

-- Manually inserting id = 5 makes the next automatic id continue from 6.
INSERT INTO auto_inc_example (id, full_name)
VALUES (5, 'Amit Singh');

INSERT INTO auto_inc_example (full_name)
VALUES ('Nikhil Jain');

SELECT * FROM auto_inc_example;

-- =========================================================
-- 13. LIMIT and ORDER BY
-- =========================================================

SELECT * FROM employees;

-- Return only two rows.
SELECT *
FROM employees
LIMIT 2;

-- Sort employees alphabetically by name.
SELECT *
FROM employees
ORDER BY full_name ASC;

-- Sort employees by name in descending order.
SELECT *
FROM employees
ORDER BY full_name DESC;

-- Sort by department in ascending order and salary in descending order.
SELECT *
FROM employees
ORDER BY department, salary DESC;

-- Find the employee with the highest salary.
SELECT *
FROM employees
ORDER BY salary DESC
LIMIT 1;

-- Find the employee with the lowest salary.
SELECT *
FROM employees
ORDER BY salary ASC
LIMIT 1;

-- =========================================================
-- 14. LIKE operator
-- =========================================================

/*
    LIKE is used for pattern matching.
    % means zero, one, or many characters.
    _ means exactly one character.
*/

-- Names starting with 'S'.
SELECT *
FROM employees
WHERE full_name LIKE 'S%';

-- Names starting with 'Sh'.
SELECT *
FROM employees
WHERE full_name LIKE 'Sh%';

-- Names ending with 'a'.
SELECT *
FROM employees
WHERE full_name LIKE '%a';

-- Names starting with 'S' and ending with 'a'.
SELECT *
FROM employees
WHERE full_name LIKE 'S%a';

-- Names where the first name has exactly five characters before the first space.
SELECT *
FROM employees
WHERE full_name LIKE '_____ %';

-- Names containing the word 'Sharma'.
SELECT *
FROM employees
WHERE full_name LIKE '%Sharma%';