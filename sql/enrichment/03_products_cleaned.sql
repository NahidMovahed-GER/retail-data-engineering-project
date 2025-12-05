-- 03_products_cleaned.sql
-- Zweck:
-- Aus retail_raw_v2 alle Produkte analysieren
-- Häufigste Beschreibung = master_description
-- Alle anderen Varianten = alternative_descriptions (Array)

CREATE TABLE IF NOT EXISTS products_cleaned (
    stockcode TEXT PRIMARY KEY,
    master_description TEXT,
    alternative_descriptions TEXT[]
);

WITH s AS (
    SELECT
        stockcode,
        description,
        COUNT(*) AS cnt,
        ROW_NUMBER() OVER (
            PARTITION BY stockcode
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM retail_raw_v2
    GROUP BY stockcode, description
)
INSERT INTO products_cleaned (stockcode, master_description, alternative_descriptions)
SELECT
    stockcode,
    description AS master_description,
    (
        SELECT ARRAY_AGG(description ORDER BY cnt DESC)
        FROM s s2
        WHERE s2.stockcode = s.stockcode
        AND s2.rn > 1
    ) AS alternative_descriptions
FROM s
WHERE rn = 1;
