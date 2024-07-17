

SELECT * FROM sales.customers;
SELECT * FROM sales.transations;
SELECT * FROM sales.products;
SELECT * FROM sales.markets;
SELECT * FROM sales.date;


-- We have to present few insights after understanding the data and come up with analysis

-- 1. Fetch the customer details along with their total transaction amount.

SELECT c.custmer_name, c.customer_type, SUM(t.sales_amount) AS total_transaction_amount
FROM sales.customers AS c
JOIN sales.transactions AS t ON c.customer_code = t.customer_code
GROUP BY c.custmer_name, c.customer_type;

-- 2. List products along with the number of transactions for each product.

SELECT p.product_code, p.product_type, COUNT(t.product_code) AS num_of_transaction
FROM sales.products p
JOIN sales.transactions t ON p.product_code = t.product_code
GROUP BY p.product_code, p.product_type;

-- 3. Calculate the average transaction amount for each customer and list customers with an average transaction amount greater than a specific value.

SELECT c.custmer_name, ROUND(AVG(t.sales_amount), 2) AS avg_transaction
FROM sales.customers AS c
JOIN sales.transactions AS t ON c.customer_code = t.customer_code
GROUP BY c.custmer_name
HAVING  avg_transaction > 1000; -- here 1000 is the specific value or we can replace it with total average of the transaction amount


-- 4. Calculate the running total of transactions for each customer.

SELECT c.custmer_name, c.customer_code, t.order_date, 
       SUM(t.sales_amount) OVER(PARTITION BY c.customer_code ORDER BY t.order_date) AS running_total
FROM sales.customers c
JOIN sales.transactions t
ON c.customer_code = t.customer_code
ORDER BY c.customer_code, t.order_date;

-- 5. Identify the top 3 markets based on transaction count using a window function.

WITH top_market AS (
SELECT m.markets_code, m.markets_name, COUNT(t.sales_qty) AS transaction_count,
       ROW_NUMBER() OVER (ORDER BY COUNT(t.sales_qty) DESC) AS ranking
  FROM sales.markets m
  JOIN sales.transactions t ON m.markets_code = t.market_code
GROUP BY m.markets_code, m.markets_name
)
SELECT markets_name, markets_code
FROM top_market
WHERE ranking <=3;

-- 6. List the customers who have made more than 5 transactions in any single month.

SELECT c.custmer_name, d.month_name, COUNT(t.sales_qty) as transaction_count
FROM sales.customers c 
JOIN sales.transactions t ON c.customer_code = t.customer_code
JOIN sales.date d ON t.order_date = d.date
GROUP BY c.custmer_name, d.month_name
HAVING COUNT(t.sales_qty) > 5;
 

-- 7. Identify customers who have made transactions in more than 3 different markets.
 
 SELECT c.custmer_name
 FROM sales.customers c 
 JOIN sales.transactions t  ON c.customer_code = t.customer_code
 GROUP BY c.custmer_name
 HAVING COUNT(t.market_code) > 3;
 
 -- 8. Find the product with the second highest selling price.

SELECT product_type, sales_amount
FROM (SELECT p.product_type, ROW_NUMBER() OVER (ORDER BY sales_amount DESC) as ranking, t.sales_amount
	   FROM sales.products p
       JOIN sales.transactions t ON p.product_code = t.product_code
       ) ranking_sales
WHERE ranking = 2;
      
-- 9. Calculate the cumulative transaction amount for each market.

SELECT m.markets_name, t.sales_amount, SUM(t.sales_amount) OVER(PARTITION BY t.market_code ORDER BY t.order_date DESC) AS cummulative_amount
FROM sales.markets m
JOIN sales.transactions t ON m.markets_code = t.market_code;

-- 10. Identify the top 5 products based on total transaction amount using a window function.

WITH top_product AS (
   SELECT p.product_code, p.product_type, SUM(t.sales_amount) AS total_amount, ROW_NUMBER() OVER(ORDER BY t.sales_amount DESC) AS ranking
   FROM sales.products p
   JOIN sales.transactions t ON p.product_code = t.product_code
   GROUP BY p.product_type, t.sales_amount, p.product_code
)
SELECT product_code, product_type, total_amount
FROM top_product
WHERE ranking <= 5;

-- 11. List the markets where the average transaction amount is greater than the overall average transaction amount.

WITH overall_avg AS (
    SELECT AVG(sales_amount) AS avg_amount
    FROM sales.transactions
)

SELECT m.markets_name, ROUND(AVG(t.sales_amount), 2) as avg_transaction_amount
FROM sales.markets m 
JOIN sales.transactions t ON m.markets_code = t.market_code
GROUP BY m.markets_name
HAVING AVG(t.sales_amount) > (SELECT avg_amount FROM overall_avg);



-- 12. Identify the customers who made their first transaction in the last month of the dataset.
WITH first_transaction AS (
     SELECT c.customer_code, c.custmer_name, MIN(t.order_date) AS first_transaction_date
     FROM sales.customers c 
     JOIN sales.transactions t ON c.customer_code = t.customer_code
     GROUP BY c.customer_code, c.custmer_name
),
last_month AS (
     SELECT MAX(order_date) AS max_order_date  FROM sales.transactions
),
last_month_start AS (
    SELECT 
         DATE_SUB(LAST_DAY(max_order_date), INTERVAL DAY(max_order_date) - 1 DAY) AS start_of_last_month
    FROM 
        last_month
)
SELECT customer_code, custmer_name
FROM first_transaction ft
JOIN last_month_start lms ON DATE_FORMAT('month', ft.first_transaction_date) = lms.start_of_last_month;

-- 13. Find the market with the highest average transaction amount and the lowest average transaction amount.

WITH avg_transaction AS (
     SELECT m.markets_name, ROUND(AVG(t.sales_amount), 2) AS avg_amount
     FROM sales.markets m 
     JOIN sales.transactions t ON m.markets_code = t.market_code
     GROUP BY m.markets_name
)
SELECT markets_name, avg_amount
FROM avg_transaction
WHERE avg_amount = (SELECT MAX(avg_amount) FROM avg_transaction)
   OR avg_amount = (SELECT MIN(avg_amount) FROM avg_transaction);

-- 14. List the customers along with the number of transactions they made in the highest transaction month.

WITH high_transaction AS (
     SELECT c.customer_code, c.custmer_name, COUNT(t.order_date) AS transaction_count, MONTH(t.order_date) AS month_name
     FROM sales.customers c 
     JOIN sales.transactions t ON c.customer_code = t.customer_code
     GROUP BY c.customer_code, month_name,  c.custmer_name
),

highest_transaction_month AS (
	SELECT customer_code, month_name, MAX(transaction_count) AS max_transactions
    FROM high_transaction
    GROUP BY month_name, customer_code
    ORDER BY max_transactions DESC
    LIMIT 1
)
SELECT ht.custmer_name, htm.month_name, ht.transaction_count
FROM high_transaction ht
JOIN highest_transaction_month htm ON ht.customer_code = htm.customer_code;

-- 15. Calculate the moving average of transaction amounts over a 3-month window for each market.

SELECT m.markets_name, d.year, d.month_name, t.sales_amount,
       AVG(t.sales_amount) OVER(PARTITION BY m.markets_code ORDER BY d.year, d.month_name ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg
FROM sales.markets m 
JOIN sales.transactions t ON m.markets_code = t.market_code
JOIN sales.date d ON t.order_date = d.date;

-- 16. Find the top 3 products with the highest sales quantity in each market.

SELECT p.product_code, p.product_type, SUM(t.sales_qty), ROW_NUMBER() OVER(ORDER BY t.sales_qty DESC) as ranking
FROM sales.products p 
JOIN sales.transactions t ON p.product_code = t.product_code
GROUP BY p.product_code, p.product_type, t.sales_qty


-- 17. List the markets and the number of customers who made transactions in each market.

