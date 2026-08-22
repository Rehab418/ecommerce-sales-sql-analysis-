/*
====================================================
E-Commerce Sales Analysis
====================================================

Database: PostgreSQL
Schema: dw

Description:
This SQL script contains analytical queries used
to analyze e-commerce sales performance, customer
behavior, product performance, and revenue trends.

Analysis Areas:
1. Sales & Revenue Analysis
2. Customer Analysis
3. Product Analysis
4. Time-Based Analysis
5. Advanced SQL Analysis

Author: Rehab Ali Mahmoud
====================================================
*/









select * from dw.fact_orders
select * from dw.dim_product
select * from dw.dim_shipper
select * from dw.dim_employee
select * from dw.dim_date
select * from dw.dim_customer
select * from dw.dim_category

--customer Analysis
--1.Who are the top customers by total revenue?

SELECT
    c.customer_sk,
    c.company_name,
    SUM(fo.total_sales) AS total_revenue
FROM dw.fact_orders fo
JOIN dw.dim_customer c
    ON c.customer_sk = fo.customer_sk
GROUP BY
    c.customer_sk,
    c.company_name
ORDER BY total_revenue DESC;

--2.What percentage of total revenue comes from the top 10% of customers?

WITH customer_revenue AS (
    SELECT
        c.customer_sk,
        c.company_name,
        SUM(fo.total_sales) AS total_revenue
    FROM dw.fact_orders fo
    JOIN dw.dim_customer c
        ON c.customer_sk = fo.customer_sk
    GROUP BY
        c.customer_sk,
        c.company_name
),

ranked_customers AS (
    SELECT
        *,
        NTILE(10) OVER (
            ORDER BY total_revenue DESC
        ) AS revenue_decile
    FROM customer_revenue
),

top_10 AS (
    SELECT
        customer_sk,
        company_name,
        total_revenue
    FROM ranked_customers
    WHERE revenue_decile = 1
)

SELECT
    SUM(total_revenue) AS top_10_revenue,

    SUM(SUM(total_revenue)) OVER () AS total_revenue,

    ROUND(
        SUM(total_revenue)
        / SUM(SUM(total_revenue)) OVER () * 100,
        2
    ) AS top_10_revenue_percentage
FROM top_10;

--3.Which customers are becoming less valuable over time?

WITH monthly_customer_sales AS (
    SELECT
        c.customer_sk,
        c.company_name,
        DATE_TRUNC('month', d.full_date) AS sales_month,
        SUM(fo.total_sales) AS monthly_revenue
    FROM dw.fact_orders fo
    JOIN dw.dim_customer c
        ON c.customer_sk = fo.customer_sk
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    GROUP BY
        c.customer_sk,
        c.company_name,
        DATE_TRUNC('month', d.full_date)
),

customer_trend AS (
    SELECT
        *,
        LAG(monthly_revenue) OVER (
            PARTITION BY customer_sk
            ORDER BY sales_month
        ) AS previous_month_revenue
    FROM monthly_customer_sales
),

customer_decline AS (
    SELECT
        customer_sk,
        company_name,

        COUNT(*) FILTER (
            WHERE monthly_revenue < previous_month_revenue
        ) AS declining_months,

        COUNT(*) FILTER (
            WHERE previous_month_revenue IS NOT NULL
        ) AS comparable_months

    FROM customer_trend
    GROUP BY
        customer_sk,
        company_name
)

SELECT
    customer_sk,
    company_name,
    declining_months,
    comparable_months,

    ROUND(
        declining_months::numeric
        / NULLIF(comparable_months, 0) * 100,
        2
    ) AS decline_percentage

FROM customer_decline

WHERE declining_months::numeric
      / NULLIF(comparable_months, 0) >= 0.70

ORDER BY decline_percentage DESC;

--4.What is the average time between purchases for each customer?

WITH customer_orders AS (
    SELECT DISTINCT
        fo.customer_sk,
        fo.order_id,
        d.full_date AS purchase_date
    FROM dw.fact_orders fo
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    WHERE fo.customer_sk IS NOT NULL
),

purchase_gaps AS (
    SELECT
        customer_sk,
        order_id,
        purchase_date,

        LAG(purchase_date) OVER (
            PARTITION BY customer_sk
            ORDER BY purchase_date
        ) AS previous_purchase_date

    FROM customer_orders
)

SELECT
    c.customer_sk,
    c.company_name,

    ROUND(
        AVG(
            purchase_date - previous_purchase_date
        ),
        2
    ) AS avg_days_between_purchases

FROM purchase_gaps pg

JOIN dw.dim_customer c
    ON c.customer_sk = pg.customer_sk

WHERE previous_purchase_date IS NOT NULL

GROUP BY
    c.customer_sk,
    c.company_name

ORDER BY avg_days_between_purchases;

--5. Who are the customers at risk of churn based on their last purchase date?

WITH customer_last_purchase AS (
    SELECT
        c.customer_sk,
        c.company_name,
        MAX(d.full_date) AS last_purchase_date
    FROM dw.fact_orders fo
    JOIN dw.dim_customer c
        ON c.customer_sk = fo.customer_sk
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    WHERE fo.customer_sk IS NOT NULL
    GROUP BY
        c.customer_sk,
        c.company_name
)

SELECT
    customer_sk,
    company_name,
    last_purchase_date,
    CURRENT_DATE - last_purchase_date AS days_since_last_purchase,

    CASE
        WHEN CURRENT_DATE - last_purchase_date > 180
            THEN 'High Risk'
        WHEN CURRENT_DATE - last_purchase_date > 90
            THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS churn_risk

FROM customer_last_purchase
ORDER BY days_since_last_purchase DESC;

--6.What is the Customer Lifetime Value (CLV) for each customer?

WITH customer_metrics AS (
    SELECT
        c.customer_sk,
        c.company_name,
        SUM(fo.total_sales) AS total_revenue,
        COUNT(DISTINCT fo.order_id) AS total_orders,
        MIN(d.full_date) AS first_purchase_date,
        MAX(d.full_date) AS last_purchase_date
    FROM dw.fact_orders fo
    JOIN dw.dim_customer c
        ON c.customer_sk = fo.customer_sk
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    WHERE fo.customer_sk IS NOT NULL
    GROUP BY
        c.customer_sk,
        c.company_name
)

SELECT
    customer_sk,
    company_name,
    total_revenue AS historical_clv,
    total_orders,
    first_purchase_date,
    last_purchase_date,
    last_purchase_date - first_purchase_date AS customer_lifespan_days
FROM customer_metrics
ORDER BY historical_clv DESC;

--7.How much revenue comes from repeat customers vs one-time customers?

WITH customer_orders AS (
    SELECT
        c.customer_sk,
        c.company_name,
        COUNT(DISTINCT fo.order_id) AS order_count,
        SUM(fo.total_sales) AS total_revenue
    FROM dw.fact_orders fo
    JOIN dw.dim_customer c
        ON c.customer_sk = fo.customer_sk
    WHERE fo.customer_sk IS NOT NULL
    GROUP BY
        c.customer_sk,
        c.company_name
),

customer_type AS (
    SELECT
        customer_sk,
        company_name,
        order_count,
        total_revenue,
        CASE
            WHEN order_count = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type
    FROM customer_orders
)

SELECT
    customer_type,
    COUNT(*) AS number_of_customers,
    SUM(total_revenue) AS total_revenue,
    ROUND(
        SUM(total_revenue)
        / SUM(SUM(total_revenue)) OVER () * 100,
        2
    ) AS revenue_percentage
FROM customer_type
GROUP BY customer_type
ORDER BY total_revenue DESC;

--product Analysis
--1.What are the top 10 products by revenue?

select
	p.product_sk,
	p.product_name,
	sum(fo.total_sales)  as Revenue
from dw.fact_orders fo
left outer join dw.dim_product p
on p.product_sk = fo.product_sk
group by 1,2
order by Revenue desc
limit 10

--2.What is each product's contribution % to total category revenue?
with product_sales  as (
SELECT
	p.product_sk,
    p.product_name,
    c.category_name,
    SUM(fo.total_sales) AS product_revenue
FROM dw.fact_orders fo
JOIN dw.dim_product p
    ON p.product_sk = fo.product_sk
JOIN dw.dim_category c
    ON c.category_sk = p.category_sk
GROUP BY
	p.product_sk,
    p.product_name,
    c.category_name
)

select 
	category_name,
	product_name,
	product_revenue,
	sum(product_revenue) over(partition by category_name ) as category_revenue,
	round(
			100.0*product_revenue/ 
			sum(product_revenue) over(partition by category_name ),2)
	 AS contribution_pct
from product_sales 
 
order by
	category_name,
	contribution_pct desc


--3.What is the revenue rank of each product within its category?
with product_revenue as (
select
	p.product_sk,
	p.product_name,
	c.category_name,
	sum(fo.total_sales)  as Revenue
from dw.fact_orders fo
join dw.dim_product p
on p.product_sk = fo.product_sk
join dw.dim_category c
on c.category_sk = p.category_sk
group by 1,2,3
)
select
	product_sk,
	category_name,
	rank() over(partition by category_name order by Revenue desc)
from product_revenue


--4.Which products have declining sales over time?

WITH yearly_sales AS (
    SELECT
        p.product_name,
        EXTRACT(YEAR FROM d.full_date) AS sales_year,
        SUM(fo.total_sales) AS total_sales
    FROM dw.fact_orders fo
    JOIN dw.dim_product p
        ON p.product_sk = fo.product_sk
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    GROUP BY
        p.product_name,
        EXTRACT(YEAR FROM d.full_date)
),

sales_comparison AS (
    SELECT
        product_name,
        sales_year,
        total_sales,
        LAG(total_sales) OVER (
            PARTITION BY product_name
            ORDER BY sales_year
        ) AS previous_year_sales
    FROM yearly_sales
)

SELECT
    product_name,
    sales_year,
    total_sales,
    previous_year_sales,
    total_sales - previous_year_sales AS sales_change
FROM sales_comparison
WHERE previous_year_sales IS NOT NULL
  AND total_sales < previous_year_sales
ORDER BY product_name, sales_year;

--5.Which products generate high revenue but low order volume?
WITH product_metrics AS (
    SELECT
        p.product_name,
        SUM(fo.total_sales) AS total_revenue,
        COUNT(DISTINCT fo.order_id) AS order_volume
    FROM dw.fact_orders fo
    JOIN dw.dim_product p
        ON p.product_sk = fo.product_sk
    GROUP BY p.product_name
),

ranked_products AS (
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY total_revenue DESC
        ) AS revenue_quartile,

        NTILE(4) OVER (
            ORDER BY order_volume ASC
        ) AS order_volume_quartile
    FROM product_metrics
)

SELECT
    product_name,
    total_revenue,
    order_volume
FROM ranked_products
WHERE revenue_quartile = 1
  AND order_volume_quartile = 1
ORDER BY total_revenue DESC;

--6.Which products are consistently among the top performers month over month?

WITH monthly_sales AS (
    SELECT
        p.product_name,
        DATE_TRUNC('month', d.full_date) AS sales_month,
        SUM(fo.total_sales) AS monthly_sales
    FROM dw.fact_orders fo
    JOIN dw.dim_product p
        ON p.product_sk = fo.product_sk
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    GROUP BY
        p.product_name,
        DATE_TRUNC('month', d.full_date)
),

monthly_ranking AS (
    SELECT
        product_name,
        sales_month,
        monthly_sales,
        ROW_NUMBER() OVER (
            PARTITION BY sales_month
            ORDER BY monthly_sales DESC
        ) AS monthly_rank
    FROM monthly_sales
)

SELECT *
FROM monthly_ranking
WHERE monthly_rank <= 3
ORDER BY sales_month, monthly_rank;

--7.What percentage of total revenue is generated by the top 20% of products?

WITH product_revenue AS (
    SELECT
        p.product_sk,
        p.product_name,
        SUM(fo.total_sales) AS total_revenue
    FROM dw.fact_orders fo
    JOIN dw.dim_product p
        ON p.product_sk = fo.product_sk
    GROUP BY
        p.product_sk,
        p.product_name
),

ranked_products AS (
    SELECT
        *,
        NTILE(5) OVER (
            ORDER BY total_revenue DESC
        ) AS revenue_group
    FROM product_revenue
),

top_20 AS (
    SELECT
        product_name,
        total_revenue
    FROM ranked_products
    WHERE revenue_group = 1
)

SELECT
    SUM(total_revenue) AS top_20_revenue,
    SUM(SUM(total_revenue)) OVER () AS total_revenue,
    ROUND(
        SUM(total_revenue)
        / SUM(SUM(total_revenue)) OVER () * 100,
        2
    ) AS top_20_revenue_percentage
FROM top_20;


--Time series Analysis

--1.How does monthly revenue change over time?

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', d.full_date) AS sales_month,
        SUM(fo.total_sales) AS monthly_revenue
    FROM dw.fact_orders fo
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    GROUP BY
        DATE_TRUNC('month', d.full_date)
),

revenue_trend AS (
    SELECT
        sales_month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            ORDER BY sales_month
        ) AS previous_month_revenue
    FROM monthly_revenue
)

SELECT
    sales_month,
    monthly_revenue,
    previous_month_revenue,

    monthly_revenue - previous_month_revenue
        AS revenue_change,

    ROUND(
        (
            monthly_revenue - previous_month_revenue
        ) / NULLIF(previous_month_revenue, 0) * 100,
        2
    ) AS revenue_growth_pct

FROM revenue_trend
ORDER BY sales_month;


--2.What is the Month-over-Month (MoM) revenue growth?
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', d.full_date) AS sales_month,
        SUM(fo.total_sales) AS monthly_revenue
    FROM dw.fact_orders fo
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    GROUP BY
        DATE_TRUNC('month', d.full_date)
),

revenue_with_previous AS (
    SELECT
        sales_month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            ORDER BY sales_month
        ) AS previous_month_revenue
    FROM monthly_revenue
)

SELECT
    sales_month,
    monthly_revenue,
    previous_month_revenue,

    ROUND(
        (
            monthly_revenue - previous_month_revenue
        )
        / NULLIF(previous_month_revenue, 0)
        * 100,
        2
    ) AS mom_growth_pct

FROM revenue_with_previous
ORDER BY sales_month;

--3.What is the Year-over-Year (YoY) revenue growth?

WITH yearly_revenue AS (
    SELECT
        EXTRACT(YEAR FROM d.full_date) AS sales_year,
        SUM(fo.total_sales) AS yearly_revenue
    FROM dw.fact_orders fo
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    GROUP BY
        EXTRACT(YEAR FROM d.full_date)
),

revenue_with_previous AS (
    SELECT
        sales_year,
        yearly_revenue,
        LAG(yearly_revenue) OVER (
            ORDER BY sales_year
        ) AS previous_year_revenue
    FROM yearly_revenue
)

SELECT
    sales_year,
    yearly_revenue,
    previous_year_revenue,

    ROUND(
        (
            yearly_revenue - previous_year_revenue
        )
        / NULLIF(previous_year_revenue, 0)
        * 100,
        2
    ) AS yoy_growth_pct

FROM revenue_with_previous
ORDER BY sales_year;

--4.What is the 3-month moving average of revenue?

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', d.full_date) AS sales_month,
        SUM(fo.total_sales) AS monthly_revenue
    FROM dw.fact_orders fo
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    GROUP BY
        DATE_TRUNC('month', d.full_date)
)

SELECT
    sales_month,
    monthly_revenue,

    ROUND(
        AVG(monthly_revenue) OVER (
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_avg_3_months

FROM monthly_revenue
ORDER BY sales_month;

--5.Which months have unusually high or low sales compared with their historical average?

WITH monthly_sales AS (
    SELECT
        d.year,
        d.month,
        d.month_name,
        SUM(fo.total_sales) AS monthly_sales
    FROM dw.fact_orders fo
    JOIN dw.dim_date d
        ON d.date_sk = fo.order_date_sk
    GROUP BY
        d.year,
        d.month,
        d.month_name
),

historical_avg AS (
    SELECT
        month,
        month_name,
        AVG(monthly_sales) AS historical_avg_sales
    FROM monthly_sales
    GROUP BY
        month,
        month_name
)

SELECT
    ms.year,
    ms.month_name,
    ms.monthly_sales,
    ROUND(ha.historical_avg_sales::numeric, 2) AS historical_avg_sales,
    ROUND(
        ((ms.monthly_sales - ha.historical_avg_sales)
        / NULLIF(ha.historical_avg_sales, 0) * 100)::numeric,
        2
    ) AS variance_pct,

    CASE
        WHEN ms.monthly_sales > ha.historical_avg_sales * 1.20
            THEN 'Unusually High'
        WHEN ms.monthly_sales < ha.historical_avg_sales * 0.80
            THEN 'Unusually Low'
        ELSE 'Normal'
    END AS sales_status

FROM monthly_sales ms
JOIN historical_avg ha
    ON ms.month = ha.month
ORDER BY
    ms.year,
    ms.month;
	
--6.How does revenue vary by day of week / month / quarter?

SELECT
    d.day_name,
    COUNT(DISTINCT fo.order_id) AS orders,
    SUM(fo.total_sales) AS total_revenue,
    AVG(fo.total_sales) AS avg_order_revenue
FROM dw.fact_orders fo
JOIN dw.dim_date d
    ON d.date_sk = fo.order_date_sk
GROUP BY
    d.day_name,
    d.day_of_week
ORDER BY
    d.day_of_week;


