-- ============================================
-- 04_validation.sql
-- Datenqualität & Konsistenzprüfungen
-- ============================================

-- ------------------------------------------------
-- 1) Grundstatistik der Rohdaten
-- ------------------------------------------------
SELECT COUNT(*) AS gesamt_zeilen
FROM retail_raw_v2;

SELECT
    COUNT(DISTINCT invoiceno)  AS distinct_invoices,
    COUNT(DISTINCT customerid) AS distinct_customers,
    COUNT(DISTINCT stockcode)  AS distinct_products
FROM retail_raw_v2;


-- ------------------------------------------------
-- 2) Null-Werte in den Hauptspalten
-- ------------------------------------------------
SELECT
    COUNT(*) AS gesamt,
    SUM(CASE WHEN invoiceno   IS NULL THEN 1 ELSE 0 END) AS invoiceno_null,
    SUM(CASE WHEN stockcode   IS NULL THEN 1 ELSE 0 END) AS stockcode_null,
    SUM(CASE WHEN description IS NULL THEN 1 ELSE 0 END) AS description_null,
    SUM(CASE WHEN quantity    IS NULL THEN 1 ELSE 0 END) AS quantity_null,
    SUM(CASE WHEN invoicedate IS NULL THEN 1 ELSE 0 END) AS invoicedate_null,
    SUM(CASE WHEN unitprice   IS NULL THEN 1 ELSE 0 END) AS unitprice_null,
    SUM(CASE WHEN customerid  IS NULL THEN 1 ELSE 0 END) AS customerid_null,
    SUM(CASE WHEN country     IS NULL THEN 1 ELSE 0 END) AS country_null
FROM retail_raw_v2;


-- ------------------------------------------------
-- 3) Plausibilität von quantity & unitprice
--    (negative Werte, Nullpreise)
-- ------------------------------------------------

-- Negative Mengen
SELECT
    COUNT(*) AS alle,
    SUM(CASE WHEN quantity < 0 THEN 1 ELSE 0 END) AS negative_mengen
FROM retail_raw_v2;

-- Negative oder Null-Preise
SELECT
    COUNT(*) AS alle,
    SUM(CASE WHEN unitprice < 0 THEN 1 ELSE 0 END) AS negative_preise,
    SUM(CASE WHEN unitprice = 0 THEN 1 ELSE 0 END) AS zero_preise
FROM retail_raw_v2;


-- ------------------------------------------------
-- 4) Prüfen, ob nach der Bereinigung noch leere
--    Strings in customerid existieren
--    (sollte 0 sein, customerid ist INTEGER)
-- ------------------------------------------------
SELECT COUNT(*) AS leere_customerid_strings
FROM retail_raw_v2
WHERE customerid::text = '';


-- ------------------------------------------------
-- 5) Konsistenz: Rohdaten vs. customers/products
-- ------------------------------------------------

-- Anzahl Kunden in customers
SELECT COUNT(*) AS dim_customers
FROM customers;

-- Anzahl distinct Kunden in Raw (ohne NULL)
SELECT COUNT(DISTINCT customerid) AS raw_customers
FROM retail_raw_v2
WHERE customerid IS NOT NULL;

-- Verkäufe mit CustomerID, die NICHT in customers stehen
SELECT COUNT(*) AS fehlende_kunden
FROM retail_raw_v2 r
LEFT JOIN customers c USING (customerid)
WHERE r.customerid IS NOT NULL
  AND c.customerid IS NULL;


-- Produkte

-- Anzahl Produkte in products
SELECT COUNT(*) AS dim_products
FROM products;

-- Anzahl distinct Stockcodes im Raw
SELECT COUNT(DISTINCT stockcode) AS raw_products
FROM retail_raw_v2
WHERE stockcode IS NOT NULL;

-- Gibt es Stockcodes im Raw, die NICHT in products gelandet sind?
SELECT COUNT(*) AS fehlende_products
FROM retail_raw_v2 r
LEFT JOIN products p USING (stockcode)
WHERE r.stockcode IS NOT NULL
  AND p.stockcode IS NULL;


-- ------------------------------------------------
-- 6) Rechnungen / invoices
-- ------------------------------------------------

-- Anzahl Rechnungen in invoices
SELECT COUNT(*) AS dim_invoices
FROM invoices;

-- Anzahl distinct Rechnungen mit CustomerID in Raw
SELECT COUNT(DISTINCT invoiceno) AS raw_invoices
FROM retail_raw_v2
WHERE customerid IS NOT NULL;

-- Zeilen im Raw mit CustomerID, aber ohne passende Rechnung
SELECT COUNT(*) AS zeilen_ohne_invoice
FROM retail_raw_v2 r
LEFT JOIN invoices i USING (invoiceno)
WHERE r.customerid IS NOT NULL
  AND i.invoiceno IS NULL;


-- ------------------------------------------------
-- 7) Stockcodes mit mehreren verschiedenen Beschreibungen
-- ------------------------------------------------
SELECT
    stockcode,
    COUNT(DISTINCT description) AS verschiedene_beschreibungen
FROM retail_raw_v2
WHERE stockcode IS NOT NULL
GROUP BY stockcode
HAVING COUNT(DISTINCT description) > 1
ORDER BY stockcode
LIMIT 20;     -- nur Stichprobe


-- ------------------------------------------------
-- 8) Gesamtkonsistenz: fehlen irgendwo Dimensionen?
--    (kunden, produkte, invoices)
-- ------------------------------------------------
SELECT COUNT(*) AS problemrows
FROM retail_raw_v2 r
LEFT JOIN customers c USING (customerid)
LEFT JOIN products  p USING (stockcode)
LEFT JOIN invoices  i USING (invoiceno)
WHERE r.customerid IS NOT NULL      -- nur Bestellungen mit Kunde
  AND (
        c.customerid IS NULL
     OR p.stockcode  IS NULL
     OR i.invoiceno  IS NULL
  );
