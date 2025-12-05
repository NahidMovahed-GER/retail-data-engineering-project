-- =====================================================================
-- 01 - CLEAN CUSTOMERID
-- Zweck:
--  - CustomerID aus der Roh-Datei ist z.B. '17850.0'
--  - Wir entfernen das '.0' und wandeln auf INTEGER
--  - Vorbereitung für Primary Keys / Foreign Keys
-- =====================================================================

-- ---------------------------------------------------------------------
-- Schritt 0: Kurzer Überblick über den aktuellen Zustand (optional)
-- ---------------------------------------------------------------------
-- Wie viele Zeilen gibt es insgesamt?
-- Wie viele CustomerIDs sind NULL (Bestellungen ohne Kunde)?
SELECT
    COUNT(*)                          AS total_rows,
    SUM(CASE WHEN customerid IS NULL THEN 1 ELSE 0 END) AS null_customerids
FROM retail_raw_v2;

-- ---------------------------------------------------------------------
-- Schritt 1: '.0' am Ende entfernen (z.B. '17850.0' -> '17850')
-- ---------------------------------------------------------------------
UPDATE retail_raw_v2
SET customerid = regexp_replace(customerid, '\.0$', '')
WHERE customerid LIKE '%.0';

-- Wie viele Zeilen hatten überhaupt ein '.0'?
SELECT
    COUNT(*) AS rows_with_decimal_customerid
FROM retail_raw_v2
WHERE customerid LIKE '%.0';

-- ---------------------------------------------------------------------
-- Schritt 2: Datentyp von TEXT auf INTEGER ändern
-- ---------------------------------------------------------------------
ALTER TABLE retail_raw_v2
ALTER COLUMN customerid TYPE INTEGER
USING customerid::INTEGER;

-- ---------------------------------------------------------------------
-- Schritt 3: Validierung nach der Umwandlung
-- ---------------------------------------------------------------------

-- 3a) Gibt es noch "komische" CustomerIDs?
--     (<= 0 wäre verdächtig, sollte 0 Zeilen liefern)
SELECT
    COUNT(*) AS invalid_customerids
FROM retail_raw_v2
WHERE customerid IS NOT NULL
  AND customerid <= 0;

-- 3b) Wie viele eindeutige Kunden gibt es jetzt?
SELECT
    COUNT(DISTINCT customerid) AS distinct_customers
FROM retail_raw_v2
WHERE customerid IS NOT NULL;

-- 3c) Kontrolle: Anzahl Zeilen mit Kunde vs. ohne Kunde
SELECT
    COUNT(*)                                           AS total_rows,
    SUM(CASE WHEN customerid IS NOT NULL THEN 1 ELSE 0 END) AS rows_with_customer,
    SUM(CASE WHEN customerid IS NULL     THEN 1 ELSE 0 END) AS rows_without_customer
FROM retail_raw_v2;

-- =====================================================================
-- Ergebnis:
--  - Alle '17850.0'-artigen Werte sind bereinigt
--  - customerid ist jetzt INTEGER
--  - Es gibt nur noch sinnvolle, positive CustomerIDs
--  - NULL bleibt erlaubt = Bestellungen ohne bekannte Kundennummer
-- =====================================================================
