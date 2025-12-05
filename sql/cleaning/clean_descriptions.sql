-- 1. Anzahl unterschiedlicher Beschreibungen pro Stockcode
SELECT
    stockcode,
    COUNT(DISTINCT description) AS beschreibung_varianten
FROM retail_raw_v2
WHERE stockcode IS NOT NULL
GROUP BY stockcode
HAVING COUNT(DISTINCT description) > 1
ORDER BY beschreibung_varianten DESC;

-- 2. Details für einen speziellen Stockcode (Debug)
SELECT
    stockcode,
    description,
    COUNT(*) AS vorkommen
FROM retail_raw_v2
WHERE stockcode = '15058A'  -- Beispiel
GROUP BY stockcode, description
ORDER BY vorkommen DESC;
