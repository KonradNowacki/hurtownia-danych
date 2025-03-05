USE hurtownia;

ALTER TABLE sales MODIFY COLUMN ORDERNUMBER BIGINT;
ALTER TABLE sales MODIFY COLUMN QUANTITYORDERED INT;
ALTER TABLE sales MODIFY COLUMN PRICEEACH DOUBLE;
ALTER TABLE sales MODIFY COLUMN ORDERLINENUMBER INT;
ALTER TABLE sales MODIFY COLUMN SALES INT;
ALTER TABLE sales MODIFY COLUMN QTR_ID INT;
ALTER TABLE sales MODIFY COLUMN MONTH_ID INT;
ALTER TABLE sales MODIFY COLUMN YEAR_ID INT;
ALTER TABLE sales MODIFY COLUMN MSRP INT;

UPDATE sales SET ORDERDATE = STR_TO_DATE(ORDERDATE, '%c/%e/%Y %H:%i');
ALTER TABLE sales MODIFY COLUMN ORDERDATE DATE;

DELIMITER //
CREATE PROCEDURE create_dim_date()
BEGIN
    CREATE TABLE IF NOT EXISTS dim_date (
        date_key DATE PRIMARY KEY,
        day INT,
        month INT,
        month_name VARCHAR(20),
        quarter INT,
        year INT
    );
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE create_dim_customer()
BEGIN
    CREATE TABLE IF NOT EXISTS dim_customer (
        customer_id INT AUTO_INCREMENT PRIMARY KEY,
        customer_name VARCHAR(100),
        phone VARCHAR(20),
        address_line1 VARCHAR(100),
        address_line2 VARCHAR(100),
        city VARCHAR(50),
        state VARCHAR(50),
        postal_code VARCHAR(20),
        country VARCHAR(50),
        territory VARCHAR(50),
        contact_last_name VARCHAR(50),
        contact_first_name VARCHAR(50),
		total_orders INT DEFAULT 0,
		total_sales DECIMAL(15,2) DEFAULT 0.00
    );
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE create_dim_product()
BEGIN
    CREATE TABLE IF NOT EXISTS dim_product (
        product_code VARCHAR(50) PRIMARY KEY,
        product_line VARCHAR(50),
        msrp DECIMAL(10,2)
    );
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE create_dim_dealsize()
BEGIN
    CREATE TABLE IF NOT EXISTS dim_dealsize (
        dealsize_id INT AUTO_INCREMENT PRIMARY KEY,
        dealsize_category VARCHAR(20)
    );
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE create_fact_sales()
BEGIN
    CREATE TABLE IF NOT EXISTS fact_sales (
        order_number INT,
        date_key DATE,
        customer_id INT,
        product_code VARCHAR(50),
        dealsize_id INT,
        quantity_ordered INT,
        price_each DECIMAL(10,2),
        order_line_number INT,
        sales DECIMAL(10,2),
        status VARCHAR(50),
        PRIMARY KEY (order_number, order_line_number),
        FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
        FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
        FOREIGN KEY (product_code) REFERENCES dim_product(product_code),
        FOREIGN KEY (dealsize_id) REFERENCES dim_dealsize(dealsize_id)
    );
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE insert_dim_date()
BEGIN
	INSERT INTO dim_date (date_key, day, month, month_name, quarter, year)
	SELECT DISTINCT
		ORDERDATE AS date_key,
		DAY(ORDERDATE) AS day,
		MONTH(ORDERDATE) AS month,
		MONTHNAME(ORDERDATE) AS month_name,
		QTR_ID AS quarter,
		YEAR_ID AS year
	FROM sales;
END //
DELIMITER ;

DROP PROCEDURE insert_dim_customer;
DELIMITER //
CREATE PROCEDURE insert_dim_customer()
BEGIN
	INSERT INTO dim_customer (
		customer_name, phone, address_line1, address_line2,
		city, state, postal_code, country, territory,
		contact_last_name, contact_first_name
	)
	SELECT DISTINCT
		CUSTOMERNAME, PHONE, ADDRESSLINE1, ADDRESSLINE2,
		CITY, STATE, POSTALCODE, COUNTRY, TERRITORY,
		CONTACTLASTNAME, CONTACTFIRSTNAME
	FROM sales;
    
    UPDATE dim_customer c
		JOIN (
			SELECT CUSTOMERNAME, COUNT(*) AS total_orders, SUM(SALES) AS total_sales
			FROM sales
			GROUP BY CUSTOMERNAME
		) s ON c.customer_name = s.CUSTOMERNAME
		SET c.total_orders = s.total_orders,
			c.total_sales = s.total_sales;
    
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE insert_dim_product()
BEGIN
	INSERT INTO dim_product (product_code, product_line, msrp)
	SELECT DISTINCT
		PRODUCTCODE, PRODUCTLINE, MSRP
	FROM sales;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE insert_dim_dealsize()
BEGIN
	INSERT INTO dim_dealsize (dealsize_category)
	SELECT DISTINCT
		DEALSIZE
	FROM sales;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE insert_dim_dealsize()
BEGIN
	INSERT INTO fact_sales (
		order_number, date_key, customer_id, product_code, dealsize_id,
		quantity_ordered, price_each, order_line_number, sales, status
	)
	SELECT
		s.ORDERNUMBER,
		s.ORDERDATE date_key,
		c.customer_id,
		s.PRODUCTCODE,
		d.dealsize_id,
		s.QUANTITYORDERED,
		s.PRICEEACH,
		s.ORDERLINENUMBER,
		s.SALES,
		s.STATUS
	FROM sales s
	JOIN dim_customer c ON s.CUSTOMERNAME = c.customer_name
	JOIN dim_dealsize d ON s.DEALSIZE = d.dealsize_category;
END //
DELIMITER ;

CALL create_dim_date();
CALL insert_dim_date();

CALL create_dim_customer();
CALL insert_dim_customer();

CALL create_dim_product();
CALL insert_dim_product();

CALL create_dim_dealsize();
CALL insert_dim_dealsize();

CALL create_fact_sales();
CALL insert_fact_sales();
