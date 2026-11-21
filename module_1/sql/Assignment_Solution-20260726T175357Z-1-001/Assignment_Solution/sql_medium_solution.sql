CREATE DATABASE medium_sql;

-- Solution for Question 1

SELECT
    user_id,
    ride_id,
    ride_date
FROM (
    SELECT
        user_id,
        ride_id,
        ride_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY ride_date, ride_id
        ) AS rn
    FROM medium_sql.grab_rides
    WHERE ride_status = 'COMPLETED'
) ranked_rides
WHERE rn = 3;

=========================================================

-- Solution for Question 2

SELECT
    ROUND(
        SUM(
            CASE
                WHEN origin_country <> destination_country THEN 1
                ELSE 0
            END
        ) * 100.0
        / COUNT(*),
        2
    ) AS international_percentage
FROM medium_sql.shipments;

=========================================================

-- Solution for Question 3

SELECT
    ROUND(
        CAST(SUM(
            CASE
                WHEN signup_date = preferred_activation_date THEN 1
                ELSE 0
            END
        ) AS DECIMAL(10,2))
        / COUNT(*) * 100,
        2
    ) AS immediate_activation_percent
FROM (
    SELECT
        user_id,
        signup_date,
        preferred_activation_date
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY user_id
                ORDER BY signup_date
            ) AS rn
        FROM medium_sql.subscriptions
    ) ranked_subscriptions
    WHERE rn = 1
) first_subscriptions;

=========================================================

-- Solution for Question 4

SELECT
    SUM(CASE WHEN activity_type = 'VIDEO'      THEN time_spent_min ELSE 0 END) AS video_min,
    SUM(CASE WHEN activity_type = 'QUIZ'       THEN time_spent_min ELSE 0 END) AS quiz_min,
    SUM(CASE WHEN activity_type = 'ASSIGNMENT' THEN time_spent_min ELSE 0 END) AS assignment_min
FROM medium_sql.learning_activity_logs;

=========================================================

-- Solution for Question 5

SELECT
    c.first_name,
    c.last_name
FROM medium_sql.customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM medium_sql.sales s
    JOIN medium_sql.products p
        ON s.product_id = p.product_id
    WHERE s.customer_id = c.customer_id
      AND p.brand_name = 'Fabulous'
);

=========================================================

-- Solution for Question 6

with ranked_activities as
	(select *,
		count(activity) over(partition by username) as activity_count,
		rank() over(partition by username order by startdate) as rnk
	from medium_sql.useractivity)

select username,activity,startdate,enddate from ranked_activities 
where rnk = 2 or activity_count = 1

=========================================================

-- Solution for Question 7
WITH bilingual_users AS (
    SELECT
        company_id,
        user_id
    FROM medium_sql.company_users
    WHERE language IN ('English','German')
    GROUP BY company_id, user_id
    HAVING COUNT(DISTINCT language) = 2
)
SELECT
    company_id
FROM bilingual_users
GROUP BY company_id
HAVING COUNT(DISTINCT user_id) >= 2;

=========================================================

-- Solution for Question 8 (Approach 1)

with prev_event_data as 
(
  select
    *,
    lag(event_name) over(partition by user_id order by event_date) as prev_event_name,
    lag(event_date) over(partition by user_id order by event_date) as prev_event_date
  from medium_sql.app_activity
)

select
   count(distinct user_id) as next_day_buyers_count
from prev_event_data
where prev_event_name is not null and prev_event_date is not null 
    and event_name = 'app-purchase' and prev_event_name = 'app-installed'
    and event_date = DATE_ADD(prev_event_date, INTERVAL 1 DAY);

-- Solution for Question 8 (Approach 2)
select 
  *
from medium_sql.app_activity al
join medium_sql.app_activity ar
  on al.user_id = ar.user_id and al.event_name = 'app-purchase' and ar.event_name = 'app-installed' 
  and al.event_date = DATE_ADD(ar.event_date, INTERVAL 1 DAY);

=========================================================

-- Solution for Question 9 (Handling Missing Dates)

WITH RECURSIVE paid_bookings AS (
    SELECT
        h.city,
        b.booking_date,
        SUM(b.rooms_booked * DATEDIFF(b.checkout_date, b.checkin_date)) AS paid_room_nights
    FROM medium_sql.bookings b
    JOIN medium_sql.hotels h ON h.hotel_id = b.hotel_id
    JOIN medium_sql.payments p ON p.booking_id = b.booking_id
    WHERE b.booking_status = 'CONFIRMED'
      AND p.payment_status = 'PAID'
    GROUP BY h.city, b.booking_date
),
date_range AS (
    SELECT 
        MIN(booking_date) AS start_date,
        MAX(booking_date) AS end_date
    FROM medium_sql.bookings
),
all_dates AS (
    SELECT start_date AS booking_date
    FROM date_range

    UNION ALL

    SELECT DATE_ADD(ad.booking_date, INTERVAL 1 DAY)
    FROM all_dates ad
    CROSS JOIN date_range dr
    WHERE ad.booking_date < dr.end_date
),
city_dates AS (
    SELECT DISTINCT
        h.city,
        ad.booking_date
    FROM medium_sql.hotels h
    CROSS JOIN all_dates ad
),
city_date_with_sales AS (
    SELECT
        cd.city,
        cd.booking_date,
        COALESCE(pb.paid_room_nights, 0) AS paid_room_nights
    FROM city_dates cd
    LEFT JOIN paid_bookings pb
        ON cd.city = pb.city
        AND cd.booking_date = pb.booking_date
)
SELECT
    city,
    booking_date,
    paid_room_nights,
    ROUND(
        AVG(paid_room_nights) OVER (
            PARTITION BY city
            ORDER BY booking_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS rolling_avg_7d_paid_room_nights
FROM city_date_with_sales
ORDER BY city, booking_date;

=========================================================

-- Solution for Question 10

WITH monthly_orders AS (
    SELECT DISTINCT
        customer_id,
        STR_TO_DATE(DATE_FORMAT(order_date, '%Y-%m-01'), '%Y-%m-%d') AS order_month
    FROM medium_sql.orders
),
consecutive_months AS (
    SELECT
        m1.customer_id,
        m1.order_month AS first_month,
        m2.order_month AS second_month
    FROM monthly_orders m1
    JOIN monthly_orders m2
        ON m1.customer_id = m2.customer_id
        AND m2.order_month = DATE_ADD(m1.order_month, INTERVAL 1 MONTH)
)
SELECT
    customer_id,
    DATE_FORMAT(first_month, '%Y-%m') AS first_month,
    DATE_FORMAT(second_month, '%Y-%m') AS second_month
FROM consecutive_months
ORDER BY customer_id, first_month;

=========================================================

-- Solution for Question 11

WITH all_user_pairs AS (
    SELECT
        u1.user_id AS user1_id,
        u1.username AS username1,
        u2.user_id AS user2_id,
        u2.username AS username2
    FROM medium_sql.users u1
    CROSS JOIN medium_sql.users u2
    WHERE u1.user_id < u2.user_id
),
interacted_pairs AS (
    SELECT DISTINCT
        LEAST(user_id, target_user_id) AS user1_id,
        GREATEST(user_id, target_user_id) AS user2_id
    FROM medium_sql.interactions
)
SELECT
    p.user1_id,
    p.username1,
    p.user2_id,
    p.username2
FROM all_user_pairs p
WHERE NOT EXISTS (
    SELECT 1
    FROM interacted_pairs i
    WHERE i.user1_id = p.user1_id
      AND i.user2_id = p.user2_id
)
ORDER BY p.user1_id, p.user2_id;

=========================================================

-- Solution for Question 12

WITH transaction_amounts AS (
    SELECT
        account_id,
        transaction_id,
        transaction_date,
        transaction_type,
        amount,
        CASE
            WHEN transaction_type IN ('DEPOSIT', 'TRANSFER_IN') THEN amount
            WHEN transaction_type IN ('WITHDRAWAL', 'TRANSFER_OUT') THEN -amount
        END AS net_amount
    FROM medium_sql.transactions
)
SELECT
    account_id,
    transaction_id,
    transaction_date,
    transaction_type,
    amount,
    SUM(net_amount) OVER (
        PARTITION BY account_id
        ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM transaction_amounts
ORDER BY account_id, transaction_date, transaction_id;

=========================================================

-- Solution for Question 13

with doctor_info as (
    select
       doc.doctor_id,
       doc.doctor_name,
       ap.appointment_id,
       ap.appointment_start,
       ap.appointment_end
    from medium_sql.appointments ap
    join medium_sql.doctors doc on ap.doctor_id = doc.doctor_id
),
appointment_lag as (
   select 
        *,
        lag(appointment_id, 1) over(partition by doctor_id, doctor_name order by appointment_start) as prev_appointment_id,
        lag(appointment_start, 1) over(partition by doctor_id, doctor_name order by appointment_start) as prev_appointment_start,
        lag(appointment_end, 1) over(partition by doctor_id, doctor_name order by appointment_end) as prev_appointment_end
   from doctor_info
)
select 
     doctor_id,
     doctor_name,
     prev_appointment_id as appointment1_id,
     prev_appointment_start as appointment1_start,
     prev_appointment_end as appointment1_end,
     appointment_id as appointment2_id,
     appointment_start as appointment2_start,
     appointment_end as appointment2_end
from appointment_lag
where prev_appointment_id is not null and prev_appointment_end between appointment_start and appointment_end;

=========================================================

-- Solution for Question 14

with delivery_details as (
   select 
      *,
      case
      	when extract(hour from pickup_time) >=6 and extract(hour from pickup_time) < 12 then 'Morning'
      	when extract(hour from pickup_time) >=12 and extract(hour from pickup_time) < 18 then 'Afternoon'
      	else 'Evening'
      end as time_window,
      case
      	when delivery_time <= estimated_time then 1
      	else 0
      end as is_on_time,
      TIMESTAMPDIFF(MINUTE, pickup_time, delivery_time) as delivery_time_minutes  
   from medium_sql.deliveries
)

select 
   time_window,
   count(*) as total_deliveries,
   sum(is_on_time) as on_time_deliveries,
   round( (sum(is_on_time) * 100.0) / count(*)  ,  2) as on_time_rate,
   round( avg(delivery_time_minutes)  ,  2) as average_delivery_time_minutes
from delivery_details
group by time_window;

=========================================================

-- Solution for Question 15

with enrollments_with_flags as (
   select
       c.course_id,
       c.course_name,
       c.launch_date,
       e.enrollment_id,
       e.enrollment_date,
       case
       	 when e.enrollment_date <= DATE_ADD(c.launch_date, INTERVAL 7 DAY) then 1
       	 else 0
       end as is_early_enrollment   
   from medium_sql.enrollments e
   join medium_sql.courses c on c.course_id = e.course_id
)

select 
    course_id,
    course_name,
    count(*) as total_enrollments,
    sum(is_early_enrollment) as early_enrollments,
    round( (sum(is_early_enrollment) * 100.0) / count(*)   , 2) as early_enrollment_rate
from enrollments_with_flags
group by course_id, course_name
having count(*) >= 10;

=========================================================

-- Solution for Question 16

with order_classification as (
   select 
      o.restaurant_id,
      r.restaurant_name,
      o.order_id,
      o.rating,
      case 
      	when extract(hour from order_time) between 17 and 21 then 'peak'
      	else 'off_peak'
      end as time_period 
   from medium_sql.food_orders o
   join medium_sql.restaurants r on o.restaurant_id = r.restaurant_id
)

select 
    restaurant_id,
    restaurant_name,
    avg( case when time_period = 'peak' then rating end ) as peak_avg_rating,
    avg( case when time_period = 'off_peak' then rating end ) as off_peak_avg_rating,
    sum( case when time_period = 'peak' then 1 else 0 end ) as peak_order_count,
    sum( case when time_period = 'off_peak' then 1 else 0 end ) as off_peak_order_count
from order_classification 
group by restaurant_id, restaurant_name
order by restaurant_id;

=========================================================

-- Solution for Question 17

with salary_with_rank as (
   select 
       employee_id,
       salary_date,
       DATE_FORMAT(salary_date, '%Y-%m') as month_year,
       monthly_salary,
       row_number() over(partition by employee_id order by salary_date desc) as recency_rank
   from medium_sql.salary_history
)

select 
   employee_id,
   month_year,
   monthly_salary,
   sum(monthly_salary) over(partition by employee_id order by month_year) as cumulative_salary
from salary_with_rank
where recency_rank > 1;

=========================================================

-- Solution for Question 18

with transactions_with_flags as (
   select 
       c.customer_id,
       c.customer_name,
       t.transaction_date,
       t.is_valid,
       lag(t.transaction_date, 1) over(partition by c.customer_id, c.customer_name order by t.transaction_date) as prev_transaction_date,
       lag(t.is_valid, 1) over(partition by c.customer_id, c.customer_name order by t.transaction_date) as prev_is_valid
   from medium_sql.txn_transactions t
   join medium_sql.txn_customers c on t.customer_id = c.customer_id
)
select
    customer_id,
    customer_name,
    prev_transaction_date as invalid_transaction_date,
    transaction_date as valid_transaction_date,
    DATEDIFF(transaction_date, prev_transaction_date) as days_between
from transactions_with_flags
where prev_transaction_date is not null and prev_is_valid = false and is_valid = true 
and DATEDIFF(transaction_date, prev_transaction_date) <=30 
order by customer_id;
