# E_commerce-sales-sql-analysis-
SQL-based analysis of e-commerce sales data using PostgreSQL to uncover customer behavior, product performance, and revenue trends.

# E_Commerce Sales Analysis

## 📌 Project Overview

This project analyzes e-commerce sales data using **PostgreSQL** and **SQL** to uncover insights into sales performance, customer behavior, product performance, and revenue trends.

The analysis focuses on answering practical business questions and demonstrates the use of advanced SQL techniques for data analysis.

---

## 🎯 Business Questions

The analysis answers questions such as:

### Sales & Revenue Analysis

* How does monthly revenue change over time?
* What is the Month-over-Month (MoM) revenue growth?
* What is the Year-over-Year (YoY) revenue growth?
* What is the 3-month moving average of revenue?
* How does revenue vary by day of week, month, and quarter?

### Customer Analysis

* What is the Customer Lifetime Value (CLV)?
* How much revenue comes from repeat customers vs. one-time customers?
* Which customers generate the highest revenue?

### Product Analysis

* Which products generate the highest revenue?
* What is the revenue rank of each product within its category?
* Which products show declining sales performance?

---

## 🛠️ Tools & Technologies

* **PostgreSQL**
* **SQL**
* Git & GitHub

---

## 🧠 SQL Techniques Used

This project demonstrates practical use of:

* `JOIN` / `LEFT JOIN`
* `GROUP BY`
* `CASE WHEN`
* `COALESCE`
* Common Table Expressions (**CTEs**)
* Subqueries
* Aggregate Functions
* Window Functions

  * `ROW_NUMBER()`
  * `RANK()`
  * `LAG()`
  * `NTILE()`
* Date & Time Functions
* `PARTITION BY`
* `ORDER BY`
* Conditional Aggregation
* MoM & YoY calculations
* Moving Averages
* Customer Segmentation

---

## 📊 Data Model

The analysis is based on a **Star Schema** consisting of:

* `fact_orders` — transactional sales data
* `dim_product` — product information
* `dim_customer` — customer information
* `dim_category` — product category information
* `dim_date` — date-related attributes

This structure allows efficient analytical queries across sales, customers, products, and time.

---

## 📁 Project Structure

```text
E-Commerce-Sales-Analysis/
│
├── README.md
│
└── sql/
    └── ecommerce_sales_analysis.sql
```

---

## 🚀 Project Goal

The goal of this project is to demonstrate how SQL can be used to transform transactional e-commerce data into meaningful business insights and support data-driven decision making.

---

## 👩‍💻 Author

**Rehab Ali Mahmoud**

Junior Data Analyst | SQL | Power BI | Python

