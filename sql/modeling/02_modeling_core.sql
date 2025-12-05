-- ############################################################
-- 02_modeling_core.sql
-- Normalisierung der Rohdaten aus retail_raw_v2
-- ############################################################

-- Sicherheit: alte Tabellen löschen, falls schon vorhanden
DROP TABLE IF EXISTS invoice_lines CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

------------------------------------------------------------
-- 1) customers  (jeder Kunde genau einmal)
------------------------------------------------------------

CREATE TABLE customers (
    customerid INTEGER PRIMARY KEY,
    country    VARCHAR(100)
);

INSERT INTO customers (customerid, country)
SELECT DISTINCT customerid, country
FROM retail_raw_v2
WHERE customerid IS NOT NULL
ON CONFLICT (customerid) DO NOTHING;


------------------------------------------------------------
-- 2) products  (jedes Produkt genau einmal)
------------------------------------------------------------

CREATE TABLE products (
    stockcode   VARCHAR(20) PRIMARY KEY,
    description VARCHAR(255)
);

INSERT INTO products (stockcode, description)
SELECT DISTINCT stockcode, description
FROM retail_raw_v2
WHERE stockcode IS NOT NULL
ON CONFLICT (stockcode) DO NOTHING;


------------------------------------------------------------
-- 3) invoices  (jede Rechnung genau einmal)
------------------------------------------------------------

CREATE TABLE invoices (
    invoiceno   VARCHAR(20) PRIMARY KEY,
    customerid  INTEGER REFERENCES customers(customerid),
    invoicedate DATE
);

-- Hinweis: hier direkt nur das Datum extrahieren
INSERT INTO invoices (invoiceno, customerid, invoicedate)
SELECT DISTINCT
    invoiceno,
    customerid,
    CAST(invoicedate AS DATE) AS invoicedate
FROM retail_raw_v2
WHERE customerid IS NOT NULL
  AND invoiceno IS NOT NULL
ON CONFLICT (invoiceno) DO NOTHING;


------------------------------------------------------------
-- 4) invoice_lines  (Rechnungspositionen / Faktentabelle)
------------------------------------------------------------

CREATE TABLE invoice_lines (
    line_id    BIGSERIAL PRIMARY KEY,
    invoiceno  VARCHAR(20) REFERENCES invoices(invoiceno),
    stockcode  VARCHAR(20) REFERENCES products(stockcode),
    quantity   INTEGER      NOT NULL,
    unitprice  NUMERIC(10,2) NOT NULL
);

INSERT INTO invoice_lines (invoiceno, stockcode, quantity, unitprice)
SELECT
    invoiceno,
    stockcode,
    quantity,
    unitprice
FROM retail_raw_v2
WHERE customerid IS NOT NULL
  AND invoiceno IS NOT NULL
  AND stockcode IS NOT NULL;


------------------------------------------------------------
-- 5) dim_date  (Datumstabelle für Analysen)
------------------------------------------------------------

CREATE TABLE dim_date (
    date_key   DATE PRIMARY KEY,
    year       INT,
    month      INT,
    month_name TEXT,
    day        INT,
    weekday    INT,
    week       INT,
    quarter    INT
);

INSERT INTO dim_date (date_key, year, month, month_name, day, weekday, week, quarter)
SELECT
    d::date                       AS date_key,
    EXTRACT(YEAR  FROM d)::INT    AS year,
    EXTRACT(MONTH FROM d)::INT    AS month,
    TO_CHAR(d, 'Mon')             AS month_name,
    EXTRACT(DAY   FROM d)::INT    AS day,
    EXTRACT(DOW   FROM d)::INT    AS weekday,
    EXTRACT(WEEK  FROM d)::INT    AS week,
    EXTRACT(QUARTER FROM d)::INT  AS quarter
FROM generate_series('2010-01-01'::date, '2012-12-31'::date, '1 day') AS d;
