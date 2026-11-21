-- How to use IS NULL or IS NOT NULL in the where clause
CREATE TABLE job_applications (
    application_id INT PRIMARY KEY,
    candidate_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    resume_link VARCHAR(255),
    referred_by VARCHAR(100),
    interview_date DATE,
    final_status VARCHAR(30)
);

INSERT INTO job_applications
(application_id, candidate_name, email, phone, resume_link, referred_by, interview_date, final_status)
VALUES
(1, 'Amit Sharma', 'amit@example.com', '9876543210', 'resume_amit.pdf', 'Rahul', '2026-06-20', 'Selected'),
(2, 'Priya Mehta', 'priya@example.com', NULL, 'resume_priya.pdf', NULL, '2026-06-21', 'Rejected'),
(3, 'Karan Verma', 'karan@example.com', '9123456780', NULL, 'Sneha', NULL, NULL),
(4, 'Neha Gupta', 'neha@example.com', NULL, NULL, NULL, NULL, NULL),
(5, 'Rohit Jain', 'rohit@example.com', '9988776655', 'resume_rohit.pdf', NULL, '2026-06-25', NULL),
(6, 'Sneha Kapoor', 'sneha@example.com', '9090909090', NULL, 'Amit', '2026-06-23', 'On Hold'),
(7, 'Vikas Singh', 'vikas@example.com', NULL, 'resume_vikas.pdf', 'Rahul', NULL, NULL),
(8, 'Anjali Rao', 'anjali@example.com', '9345678901', 'resume_anjali.pdf', NULL, '2026-06-24', 'Selected');

select * from job_applications;

-- Find applications where interview is not scheduled yet
SELECT application_id, candidate_name, interview_date
FROM job_applications
WHERE interview_date IS NULL;

-- Find candidates who came through referral
SELECT application_id, candidate_name, referred_by
FROM job_applications
WHERE referred_by IS NOT NULL;

-- Find candidates who have submitted resume but final status is pending
SELECT application_id, candidate_name, resume_link, final_status
FROM job_applications
WHERE resume_link IS NOT NULL
  AND final_status IS NULL;

-- Count missing values column-wise
SELECT
    COUNT(*) AS total_applications,
    SUM(phone IS NULL) AS missing_phone_count,
    SUM(resume_link IS NULL) AS missing_resume_count,
    SUM(interview_date IS NULL) AS interview_not_scheduled_count,
    SUM(final_status IS NULL) AS pending_result_count
FROM job_applications;

-- Group By & Having Clause

CREATE TABLE food_orders (
    order_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    restaurant_name VARCHAR(100),
    cuisine_type VARCHAR(50),
    order_status VARCHAR(30),
    payment_method VARCHAR(30),
    order_date DATE,
    order_amount DECIMAL(10,2),
    delivery_fee DECIMAL(10,2),
    customer_rating INT
);

INSERT INTO food_orders
(order_id, customer_name, city, restaurant_name, cuisine_type, order_status,
 payment_method, order_date, order_amount, delivery_fee, customer_rating)
VALUES
(1, 'Amit Sharma', 'Delhi', 'Burger Hub', 'Fast Food', 'Delivered', 'UPI', '2026-06-01', 450, 40, 5),
(2, 'Priya Mehta', 'Mumbai', 'Pizza Palace', 'Italian', 'Delivered', 'Card', '2026-06-01', 800, 60, 4),
(3, 'Rahul Verma', 'Delhi', 'Biryani House', 'Indian', 'Delivered', 'UPI', '2026-06-02', 650, 50, 5),
(4, 'Sneha Kapoor', 'Bangalore', 'Sushi World', 'Japanese', 'Cancelled', 'UPI', '2026-06-02', 1200, 0, 1),
(5, 'Karan Singh', 'Delhi', 'Pizza Palace', 'Italian', 'Delivered', 'Cash', '2026-06-03', 700, 50, 3),
(6, 'Neha Gupta', 'Mumbai', 'Burger Hub', 'Fast Food', 'Delivered', 'UPI', '2026-06-03', 500, 40, 4),
(7, 'Rohit Jain', 'Pune', 'Biryani House', 'Indian', 'Cancelled', 'Card', '2026-06-04', 750, 0, 2),
(8, 'Anjali Rao', 'Bangalore', 'Pizza Palace', 'Italian', 'Delivered', 'Card', '2026-06-04', 900, 60, 5),
(9, 'Vikas Yadav', 'Delhi', 'Sushi World', 'Japanese', 'Delivered', 'UPI', '2026-06-05', 1300, 70, 4),
(10, 'Pooja Nair', 'Mumbai', 'Biryani House', 'Indian', 'Delivered', 'UPI', '2026-06-05', 680, 50, 4),
(11, 'Arjun Menon', 'Bangalore', 'Burger Hub', 'Fast Food', 'Delivered', 'UPI', '2026-06-06', 480, 40, 5),
(12, 'Divya Shah', 'Pune', 'Pizza Palace', 'Italian', 'Delivered', 'Card', '2026-06-06', 850, 60, 4),
(13, 'Mohit Agarwal', 'Delhi', 'Burger Hub', 'Fast Food', 'Cancelled', 'UPI', '2026-06-07', 420, 0, 1),
(14, 'Simran Kaur', 'Mumbai', 'Sushi World', 'Japanese', 'Delivered', 'Card', '2026-06-07', 1400, 80, 5),
(15, 'Nikhil Bansal', 'Bangalore', 'Biryani House', 'Indian', 'Delivered', 'UPI', '2026-06-08', 720, 50, 4),
(16, 'Tanvi Joshi', 'Pune', 'Burger Hub', 'Fast Food', 'Delivered', 'NetBanking', '2026-06-08', 520, 40, 3),
(17, 'Harsh Vardhan', 'Delhi', 'Pizza Palace', 'Italian', 'Delivered', 'UPI', '2026-06-09', 950, 60, 5),
(18, 'Meera Iyer', 'Mumbai', 'Biryani House', 'Indian', 'Cancelled', 'Card', '2026-06-09', 700, 0, 2),
(19, 'Saurabh Mishra', 'Bangalore', 'Sushi World', 'Japanese', 'Delivered', 'UPI', '2026-06-10', 1250, 70, 4),
(20, 'Ritika Das', 'Delhi', 'Biryani House', 'Indian', 'Delivered', 'Card', '2026-06-10', 780, 50, 5);


-- Find total orders by city
SELECT
    city,
    COUNT(*) AS total_orders
FROM food_orders
GROUP BY city;

-- Total orders placed in each city or city wise along with highest rating 
--  received in that city
select
  city,
  count(*) as city_wise_orders,
  max(customer_rating) as highest_rating
from food_orders
group by city;

-- Find total orders and total revenue by city and cuisine type.
SELECT
    city,
    cuisine_type,
    COUNT(*) AS total_orders,
    SUM(order_amount) AS total_revenue
FROM food_orders
GROUP BY city, cuisine_type
ORDER BY city, cuisine_type;

-- Find total orders, total revenue, average order value, minimum order amount, and maximum order amount by restaurant.
SELECT
    restaurant_name,
    COUNT(*) AS total_orders,
    SUM(order_amount) AS total_revenue,
    ROUND(AVG(order_amount), 2) AS avg_order_value,
    MIN(order_amount) AS min_order_amount,
    MAX(order_amount) AS max_order_amount
FROM food_orders
GROUP BY restaurant_name;

-- Find different payment methods which were used more than once WITHOUT Having

select
  *
from (select 
  payment_method,
  count(*) as total_time_used
from food_orders
group by payment_method) tmp_indata
where total_time_used > 1;

-- Find different payment methods which were used more than once With Having
select
 payment_method,
 count(*) as total_time_used
from food_orders
group by payment_method having count(*) > 1;

-- Find restaurants having total revenue greater than 4000.
SELECT
    restaurant_name,
    COUNT(*) AS total_orders,
    SUM(order_amount) AS total_revenue
FROM food_orders
GROUP BY restaurant_name
HAVING SUM(order_amount) > 4000;

-- Find restaurants that received orders from at least 3 different cities. Return restaurant_name, total orders, unique cities, total revenue
SELECT
    restaurant_name,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT city) AS unique_cities,
    SUM(order_amount) AS total_revenue
FROM food_orders
GROUP BY restaurant_name
HAVING COUNT(DISTINCT city) >= 3;


-- How to use GROUP_CONCAT

CREATE TABLE orders_data (
    order_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    country VARCHAR(50),
    state VARCHAR(50),
    city VARCHAR(50),
    order_amount DECIMAL(10,2)
);

INSERT INTO orders_data
(order_id, customer_name, country, state, city, order_amount)
VALUES
(1, 'Amit Sharma', 'India', 'Maharashtra', 'Mumbai', 1200),
(2, 'Priya Mehta', 'India', 'Maharashtra', 'Pune', 900),
(3, 'Rahul Verma', 'India', 'Karnataka', 'Bangalore', 1500),
(4, 'Sneha Kapoor', 'India', 'Karnataka', 'Mysore', 700),
(5, 'Karan Singh', 'India', 'Delhi', 'New Delhi', 1100),
(6, 'John Smith', 'USA', 'California', 'Los Angeles', 2000),
(7, 'Emma Wilson', 'USA', 'California', 'San Francisco', 2500),
(8, 'Michael Brown', 'USA', 'Texas', 'Austin', 1800),
(9, 'Sophia Davis', 'USA', 'Texas', 'Dallas', 1600),
(10, 'James Miller', 'USA', 'New York', 'New York City', 2200),
(11, 'Oliver Jones', 'UK', 'England', 'London', 1700),
(12, 'Emily Taylor', 'UK', 'England', 'Manchester', 1300),
(13, 'Harry Wilson', 'UK', 'Scotland', 'Edinburgh', 1400),
(14, 'George Martin', 'UK', 'Wales', 'Cardiff', 1000),
(15, 'Liam Anderson', 'Canada', 'Ontario', 'Toronto', 1900),
(16, 'Noah Thomas', 'Canada', 'Ontario', 'Ottawa', 1500),
(17, 'Ava Jackson', 'Canada', 'Quebec', 'Montreal', 1600),
(18, 'Mia White', 'Canada', 'British Columbia', 'Vancouver', 2100);



-- Query - Write a query to print distinct states present in the dataset for each country?
SELECT 
    country, 
    GROUP_CONCAT(state) AS states_in_country
FROM orders_data
GROUP BY country;

SELECT 
    country, 
    GROUP_CONCAT(DISTINCT state) AS states_in_country
FROM orders_data
GROUP BY country;

SELECT 
    country, 
    GROUP_CONCAT(DISTINCT state ORDER BY state DESC) AS states_in_country
FROM orders_data
GROUP BY country;

SELECT 
    country, 
    GROUP_CONCAT(DISTINCT state ORDER BY state DESC SEPARATOR '<->') AS states_in_country
FROM orders_data
GROUP BY country;

--- Group RollUP

CREATE TABLE payment (payment_amount decimal(8,2), 
payment_date date, 
store_id int);
 
INSERT INTO payment
VALUES
(1200.99, '2018-01-18', 1),
(189.23, '2018-02-15', 1),
(33.43, '2018-03-03', 3),
(7382.10, '2019-01-11', 2),
(382.92, '2019-02-18', 1),
(322.34, '2019-03-29', 2),
(2929.14, '2020-01-03', 2),
(499.02, '2020-02-19', 3),
(994.11, '2020-03-14', 1),
(394.93, '2021-01-22', 2),
(3332.23, '2021-02-23', 3),
(9499.49, '2021-03-10', 3),
(3002.43, '2018-02-25', 2),
(100.99, '2019-03-07', 1),
(211.65, '2020-02-02', 1),
(500.73, '2021-01-06', 3);

--- Write a query to calculate total reveue of each shop
--- per year, also display year wise revenue NORMAL GROUP BY

SELECT
  SUM(payment_amount),
  YEAR(payment_date) AS 'Payment Year'
  store_id
FROM payment
GROUP BY YEAR(payment_date), store_id
ORDER BY YEAR(payment_date), store_id;

--- Write a query to calculate total revenue per year NORMAL GROUP BY

SELECT
  SUM(payment_amount),
  YEAR(payment_date) AS 'Payment Year'
FROM payment
GROUP BY YEAR(payment_date)
ORDER BY YEAR(payment_date);

-- Use Group By Roll to answer multiple questions from one output

SELECT
  SUM(payment_amount),
  YEAR(payment_date) AS 'Payment Year',
  store_id AS 'Store'
FROM payment
GROUP BY YEAR(payment_date), store_id WITH ROLLUP
ORDER BY YEAR(payment_date), store_id;

-- Total payment amount
Select
   total_payment
From
(SELECT
  SUM(payment_amount) as total_payment,
  YEAR(payment_date) AS Payment_Year,
  store_id AS Store
FROM payment
GROUP BY YEAR(payment_date), store_id WITH ROLLUP
ORDER BY YEAR(payment_date), store_id) temp 
Where Payment_Year is null and Store is null;

-- Total payment per year
Select
   Payment_Year,
   total_payment
From
(SELECT
  SUM(payment_amount) as total_payment,
  YEAR(payment_date) AS Payment_Year,
  store_id AS Store
FROM payment
GROUP BY YEAR(payment_date), store_id WITH ROLLUP
ORDER BY YEAR(payment_date), store_id) temp 
Where Payment_Year is not null and Store is null;

-- Total payment per year for each shop
Select
   Payment_Year,
   Store,
   total_payment
From
(SELECT
  SUM(payment_amount) as total_payment,
  YEAR(payment_date) AS Payment_Year,
  store_id AS Store
FROM payment
GROUP BY YEAR(payment_date), store_id WITH ROLLUP
ORDER BY YEAR(payment_date), store_id) temp 
Where Payment_Year is not null and Store is not null;

-- Subqueries in SQL
CREATE TABLE cab_trips (
    trip_id INT PRIMARY KEY,
    driver_id INT,
    driver_name VARCHAR(100),
    city VARCHAR(50),
    trip_date DATE,
    trip_amount DECIMAL(10,2),
    trip_distance_km DECIMAL(10,2),
    rating DECIMAL(2,1),
    trip_status VARCHAR(30)
);

INSERT INTO cab_trips
(trip_id, driver_id, driver_name, city, trip_date, trip_amount, trip_distance_km, rating, trip_status)
VALUES
(1, 101, 'Ravi Kumar', 'Delhi', '2026-06-01', 450, 12.5, 4.8, 'Completed'),
(2, 102, 'Aman Verma', 'Delhi', '2026-06-01', 320, 8.2, 4.2, 'Completed'),
(3, 103, 'Imran Khan', 'Mumbai', '2026-06-01', 700, 18.0, 4.9, 'Completed'),
(4, 104, 'Suresh Yadav', 'Bangalore', '2026-06-02', 520, 14.0, 4.5, 'Completed'),
(5, 101, 'Ravi Kumar', 'Delhi', '2026-06-02', 600, 16.5, 4.7, 'Completed'),
(6, 102, 'Aman Verma', 'Delhi', '2026-06-03', 280, 7.0, 4.0, 'Cancelled'),
(7, 103, 'Imran Khan', 'Mumbai', '2026-06-03', 850, 21.0, 4.8, 'Completed'),
(8, 105, 'Nikhil Jain', 'Mumbai', '2026-06-03', 400, 10.0, 4.1, 'Completed'),
(9, 104, 'Suresh Yadav', 'Bangalore', '2026-06-04', 750, 20.5, 4.6, 'Completed'),
(10, 106, 'Harish Rao', 'Bangalore', '2026-06-04', 300, 6.5, 3.9, 'Completed'),
(11, 101, 'Ravi Kumar', 'Delhi', '2026-06-05', 900, 24.0, 4.9, 'Completed'),
(12, 102, 'Aman Verma', 'Delhi', '2026-06-05', 350, 9.5, 4.3, 'Completed'),
(13, 103, 'Imran Khan', 'Mumbai', '2026-06-06', 950, 25.0, 5.0, 'Completed'),
(14, 105, 'Nikhil Jain', 'Mumbai', '2026-06-06', 550, 13.0, 4.4, 'Completed'),
(15, 106, 'Harish Rao', 'Bangalore', '2026-06-07', 650, 17.0, 4.2, 'Completed');

-- Scaler subquery : Find trips where the trip_amount is greater than the overall average trip amount
SELECT
    trip_id,
    driver_name,
    city,
    trip_amount
FROM cab_trips
WHERE trip_amount > (
    SELECT AVG(trip_amount)
    FROM cab_trips
    WHERE trip_status = 'Completed'
);

-- Correlated subquery : Find trips where the trip_amount is greater than the average trip amount of that same city
SELECT
    c1.trip_id,
    c1.driver_name,
    c1.city,
    c1.trip_amount
FROM cab_trips c1
WHERE c1.trip_amount > (
    SELECT AVG(c2.trip_amount)
    FROM cab_trips c2
    WHERE c2.city = c1.city
);

-- IN example - Find all trips taken by drivers who have completed at least one trip in Mumbai.
SELECT
    trip_id,
    driver_id,
    driver_name,
    city,
    trip_amount
FROM cab_trips
WHERE driver_id IN (
    SELECT DISTINCT driver_id
    FROM cab_trips
    WHERE city = 'Mumbai'
      AND trip_status = 'Completed'
);

-- NOT IN - Find drivers who have never completed a trip in Mumbai.
SELECT
    driver_id,
    driver_name,
    COUNT(*) AS total_trips
FROM cab_trips
WHERE driver_id NOT IN (
    SELECT DISTINCT driver_id
    FROM cab_trips
    WHERE city = 'Mumbai'
      AND trip_status = 'Completed'
)
GROUP BY driver_id, driver_name;


-- Case When in SQL
CREATE TABLE support_tickets (
    ticket_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    issue_type VARCHAR(50),
    priority VARCHAR(20),
    status VARCHAR(30),
    created_date DATE,
    resolved_hours INT,
    satisfaction_score INT
);

INSERT INTO support_tickets
(ticket_id, customer_name, issue_type, priority, status, created_date, resolved_hours, satisfaction_score)
VALUES
(1, 'Amit Sharma', 'Payment', 'High', 'Resolved', '2026-06-01', 3, 5),
(2, 'Priya Mehta', 'Login', 'Medium', 'Resolved', '2026-06-01', 8, 4),
(3, 'Rahul Verma', 'Delivery', 'High', 'Open', '2026-06-02', 30, 2),
(4, 'Sneha Kapoor', 'Refund', 'High', 'Resolved', '2026-06-02', 20, 3),
(5, 'Karan Singh', 'Login', 'Low', 'Resolved', '2026-06-03', 15, 4),
(6, 'Neha Gupta', 'Payment', 'Medium', 'Open', '2026-06-03', 28, 2),
(7, 'Rohit Jain', 'Delivery', 'High', 'Resolved', '2026-06-04', 5, 5),
(8, 'Anjali Rao', 'Refund', 'Medium', 'Resolved', '2026-06-04', 18, 3),
(9, 'Vikas Yadav', 'Payment', 'Low', 'Resolved', '2026-06-05', 10, 4),
(10, 'Pooja Nair', 'Login', 'High', 'Open', '2026-06-05', 40, 1),
(11, 'Arjun Menon', 'Delivery', 'Medium', 'Resolved', '2026-06-06', 12, 4),
(12, 'Divya Shah', 'Refund', 'Low', 'Resolved', '2026-06-06', 24, 3),
(13, 'Mohit Agarwal', 'Payment', 'High', 'Resolved', '2026-06-07', 4, 5),
(14, 'Simran Kaur', 'Login', 'Medium', 'Resolved', '2026-06-07', 9, 4),
(15, 'Nikhil Bansal', 'Delivery', 'Low', 'Open', '2026-06-08', 35, 2);

SELECT
    ticket_id,
    customer_name,
    issue_type,
    status,
    resolved_hours,
    CASE
        WHEN resolved_hours <= 6 THEN 'Fast Resolution'
        WHEN resolved_hours <= 24 THEN 'Normal Resolution'
        ELSE 'Delayed Resolution'
    END AS resolution_category
FROM support_tickets;

SELECT
    ticket_id,
    customer_name,
    issue_type,
    priority,
    status,
    CASE
        WHEN priority = 'High' AND status = 'Open' THEN 'Immediate Action'
        WHEN priority = 'Medium' AND status = 'Open' THEN 'Follow Up'
        WHEN status = 'Resolved' THEN 'No Action'
        ELSE 'Monitor'
    END AS action_required
FROM support_tickets;

-- Conditional aggregate : For each issue_type, calculate: total tickets, open tickets, resolved tickets, high priority tickets, fast resolved tickets, where resolved_hours <= 6, average satisfaction score
SELECT
    issue_type,
    COUNT(*) AS total_tickets,
    SUM(CASE WHEN status = 'Open' THEN 1 ELSE 0 END) AS open_tickets,
    SUM(CASE WHEN status = 'Resolved' THEN 1 ELSE 0 END) AS resolved_tickets,
    SUM(CASE WHEN priority = 'High' THEN 1 ELSE 0 END) AS high_priority_tickets,
    SUM(CASE WHEN resolved_hours <= 6 THEN 1 ELSE 0 END) AS fast_resolved_tickets,
    ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction_score
FROM support_tickets
GROUP BY issue_type;

-- Uber SQL Interview questions
create table tree
(
    node int,
    parent int
);

insert into tree values (5,8),(9,8),(4,5),(2,9),(1,5),(3,9),(8,null);

select * from tree;

select node,
       CASE
            when parent is null then 'ROOT'
            when node not in (select distinct parent from tree where parent is not null) then 'LEAF'
            else 'INNER'
       END as node_type
from tree;

-- Joins

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    city VARCHAR(50)
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    order_amount DECIMAL(10,2),
    order_status VARCHAR(30)
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50)
);

CREATE TABLE coupons (
    coupon_id INT PRIMARY KEY,
    coupon_code VARCHAR(20),
    discount_percent INT
);

CREATE TABLE product_prices (
    product_id INT,
    city VARCHAR(50),
    price DECIMAL(10,2),
    PRIMARY KEY (product_id, city)
);

CREATE TABLE order_items (
    order_id INT,
    product_id INT,
    city VARCHAR(50),
    quantity INT,
    PRIMARY KEY (order_id, product_id)
);

INSERT INTO customers
(customer_id, customer_name, city)
VALUES
(1, 'Amit Sharma', 'Delhi'),
(2, 'Priya Mehta', 'Mumbai'),
(3, 'Rahul Verma', 'Bangalore'),
(4, 'Sneha Kapoor', 'Pune'),
(5, 'Karan Singh', 'Delhi');

INSERT INTO orders
(order_id, customer_id, order_date, order_amount, order_status)
VALUES
(101, 1, '2026-06-01', 1200, 'Delivered'),
(102, 2, '2026-06-02', 2500, 'Delivered'),
(103, 1, '2026-06-03', 800, 'Cancelled'),
(104, 3, '2026-06-04', 1800, 'Delivered'),
(105, 6, '2026-06-05', 1500, 'Delivered');

INSERT INTO products
(product_id, product_name, category)
VALUES
(201, 'Laptop Bag', 'Accessories'),
(202, 'Wireless Mouse', 'Electronics'),
(203, 'Keyboard', 'Electronics');

INSERT INTO coupons
(coupon_id, coupon_code, discount_percent)
VALUES
(1, 'WELCOME10', 10),
(2, 'FESTIVE20', 20),
(3, 'SUPER30', 30);

INSERT INTO product_prices
(product_id, city, price)
VALUES
(201, 'Delhi', 1200),
(201, 'Mumbai', 1300),
(202, 'Delhi', 800),
(202, 'Mumbai', 850),
(203, 'Bangalore', 1500),
(203, 'Delhi', 1450);

INSERT INTO order_items
(order_id, product_id, city, quantity)
VALUES
(101, 201, 'Delhi', 1),
(101, 202, 'Delhi', 2),
(102, 201, 'Mumbai', 1),
(104, 203, 'Bangalore', 1),
(105, 202, 'Delhi', 1);

-- Find customers who have placed orders - Inner Join

SELECT
    c.customer_id,
    c.customer_name,
    c.city,
    o.order_id,
    o.order_amount,
    o.order_status
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id;

-- Find all customers and their orders, even if some customers have not placed any order - Left join
SELECT
    c.customer_id,
    c.customer_name,
    c.city,
    o.order_id,
    o.order_amount,
    o.order_status
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id;


-- Find all orders and their customer details, even if customer details are missing - Right join
SELECT
    o.order_id,
    o.customer_id,
    c.customer_name,
    c.city,
    o.order_amount,
    o.order_status
FROM customers c
RIGHT JOIN orders o
    ON c.customer_id = o.customer_id;

-- Create all possible product-coupon combinations - Cross join
SELECT
    p.product_name,
    c.coupon_code,
    c.discount_percent
FROM products p
CROSS JOIN coupons c;

-- Find order items with their correct city-specific product price.
SELECT
    oi.order_id,
    oi.product_id,
    oi.city,
    oi.quantity,
    pp.price,
    oi.quantity * pp.price AS total_item_amount
FROM order_items oi
INNER JOIN product_prices pp
    ON oi.product_id = pp.product_id
   AND oi.city = pp.city;