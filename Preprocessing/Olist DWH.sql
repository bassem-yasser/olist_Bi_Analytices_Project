create database DWH_Olist

GO
USE DWH_Olist
GO

-- ==========================================
--                STAGING
-- ==========================================

CREATE TABLE stg_customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city NVARCHAR(100),
    customer_state VARCHAR(5)
);
GO
CREATE TABLE stg_orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME2,
    order_approved_at DATETIME2,
    order_delivered_carrier_date DATETIME2,
    order_delivered_customer_date DATETIME2,
    order_estimated_delivery_date DATETIME2
);
GO
CREATE TABLE stg_order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME2,
    price DECIMAL(18,2),
    freight_value DECIMAL(18,2)
);
GO

-- ==========================================
--                BULK INSERT 
-- ==========================================

BULK INSERT stg_customers
FROM 'D:\ERU\BI\Project\archive\olist_customers_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a', 
    CODEPAGE = '65001',     
    TABLOCK
);
GO

BULK INSERT stg_orders
FROM 'D:\ERU\BI\Project\archive\olist_orders_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a', 
    CODEPAGE = '65001',     
    TABLOCK
);
GO

BULK INSERT stg_order_items
FROM 'D:\ERU\BI\Project\archive\olist_order_items_dataset.csv'
WITH (
     FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '0x0a', 
    CODEPAGE = '65001',     
    TABLOCK
);
GO

-- ==========================================
--                Star Schema
-- ==========================================

CREATE TABLE Dim_Customers (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY, 
    customer_id VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50),
    customer_city NVARCHAR(100),
    customer_state VARCHAR(5)
);
GO

CREATE TABLE Dim_Date (
    DateKey INT PRIMARY KEY, 
    FullDate DATE,
    Year INT,
    Quarter INT,
    Month INT,
    Day INT
);
GO

CREATE TABLE Fact_Sales (
    SalesKey INT IDENTITY(1,1) PRIMARY KEY,
    order_id VARCHAR(50),
    order_item_id INT,
    CustomerKey INT, 
    OrderDateKey INT, 
    price DECIMAL(18,2),
    freight_value DECIMAL(18,2),
    TotalAmount AS (price + freight_value) PERSISTED,
    
    CONSTRAINT FK_FactSales_Customer FOREIGN KEY (CustomerKey) REFERENCES Dim_Customers(CustomerKey),
    CONSTRAINT FK_FactSales_Date FOREIGN KEY (OrderDateKey) REFERENCES Dim_Date(DateKey)
);
GO

-- ==========================================
--             Transform & Load
-- ==========================================

INSERT INTO Dim_Customers (customer_id, customer_unique_id, customer_city, customer_state)
SELECT DISTINCT 
    customer_id, 
    customer_unique_id, 
    customer_city, 
    customer_state
FROM stg_customers;
GO

INSERT INTO Dim_Date (DateKey, FullDate, Year, Quarter, Month, Day)
SELECT DISTINCT
    CAST(FORMAT(order_purchase_timestamp, 'yyyyMMdd') AS INT),
    CAST(order_purchase_timestamp AS DATE),
    YEAR(order_purchase_timestamp),
    DATEPART(QUARTER, order_purchase_timestamp),
    MONTH(order_purchase_timestamp),
    DAY(order_purchase_timestamp)
FROM stg_orders
WHERE order_purchase_timestamp IS NOT NULL;
GO

INSERT INTO Fact_Sales (order_id, order_item_id, CustomerKey, OrderDateKey, price, freight_value)
SELECT 
    oi.order_id,
    oi.order_item_id,
    c.CustomerKey,
    CAST(FORMAT(o.order_purchase_timestamp, 'yyyyMMdd') AS INT) AS OrderDateKey,
    oi.price,
    oi.freight_value
FROM stg_order_items oi
JOIN stg_orders o ON oi.order_id = o.order_id
JOIN Dim_Customers c ON o.customer_id = c.customer_id;
GO