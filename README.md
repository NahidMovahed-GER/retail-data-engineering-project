# Online Retail Datenprojekt 

**Datenbereinigung • Datenmodellierung • Validierung • Produkttext-Normalisierung**

### 1. Überblick

In diesem Projekt habe ich aus einer großen CSV-Datei (Online Retail Dataset von Kaggle) eine saubere und logisch aufgebaute PostgreSQL-Datenbank erstellt.

Die Originaldatei enthält über 540.000 Bestellzeilen, in denen viele Informationen mehrfach vorkommen und einige Werte fehlerhaft sind.

Ziele des Projekts:

- Daten importieren
- Probleme erkennen und korrigieren
- Tabellen normalisieren (also sinnvoll aufteilen)
- Datenqualität prüfen
- Produktbeschreibungen weiter bereinigen
- Eine stabile Basis für Analysen schaffen

Ich habe bewusst Schritt für Schritt gearbeitet, damit die Struktur transparent und verständlich bleibt.

### 2. Rohdaten importieren

Die Datei `retail.csv` wurde zuerst in eine Tabelle geladen:
```
retail_raw_v2
```
Diese Tabelle enthält alle Spalten der Originaldaten:

- invoiceno
- stockcode
- description
- quantity
- invoicedate
- unitprice
- customerid
- country

Diese Tabelle bleibt unverändert bestehen und dient als Rohdatenquelle.  
Alle neuen Tabellen werden aus ihr aufgebaut.

### 3. Bereinigung der Kundennummern

Schon beim Import fiel ein Problem auf: viele Kundennummern hatten .0 am Ende, z. B.:

```
17850.0
13047.0
```
Damit lässt sich kein INTEGER erzeugen.  
Nach einer späteren Umwandlung würden Beziehungen (Foreign Keys) nicht funktionieren.

**So wurde es gelöst:**

**1.** customerid zuerst als TEXT importiert  
**2.** .0 entfernt  
**3.** danach in INTEGER umgewandelt  
**4.** geprüft, ob ungültige Werte übrig bleiben  



Ergebnis der Prüfung:

- **406 829** Zeilen haben eine gültige Kundennummer
- **135 080** Zeilen haben keine
- **4 372** eindeutige Kunden existieren

Nach dieser Bereinigung war customerid stabil und konnte als Primärschlüssel verwendet werden.

### 4. Daten normalisieren (Tabellen aufteilen)

Die Rohdaten enthalten viele Wiederholungen:

- Ein Kunde kommt tausende Male vor
- Ein Produktcode wiederholt sich ständig
- Eine Rechnung besteht aus vielen Zeilen

Um die Datenbank übersichtlich und effizient zu machen, wurde sie in mehrere Tabellen aufgeteilt.

**4.1 customers**

Jeder Kunde erscheint genau einmal.

| Spalte     | Beschreibung        |
|------------|---------------------|
| customerid | Primärschlüssel     |
| country    | Land des Kunden     |


**4.2 products**

Jeder Produktcode genau einmal.
Hilft bei Validierung und Analysen.

| Spalte      | Beschreibung                     |
|-------------|----------------------------------|
| stockcode   | Primärschlüssel                  |
| description | ursprüngliche Beschreibung       |


**4.3 invoices**

Eine Rechnung pro Zeile.
Rechnungskopf.
Eine Bestellung = eine Rechnung.

| Spalte      | Beschreibung            |
|-------------|-------------------------|
| invoiceno   | Primärschlüssel         |
| customerid  | FK → customers          |
| invoicedate | Datum der Rechnung      |

**4.4 invoice_lines**

Hier stehen alle Bestellpositionen.
Rechnungspositionen = einzelne Produkte in der Rechnung.
Hier liegt der Umsatz.

| Spalte      | Beschreibung         |
|-------------|----------------------|
| line_id     | künstlicher PK        |
| invoiceno   | FK → invoices         |
| stockcode   | FK → products         |
| quantity    | Menge                |
| unitprice   | Preis pro Stück      |


**4.5 dim_date**
Kalenderdimension.
Erlaubt Zeitanalysen (Monat, Woche, Quartal).
Eine Datumstabelle, erzeugt mit `generate_series`, damit man später leichter nach Monat, Woche, Quartal usw. filtern kann.


### 5. Datenbankmodell (ERD)

Die Tabellen sind als Sternschema aufgebaut:  
Kunden, Produkte und Datum sind die Dimensionstabellen.  
Die Tabellen `invoices` und `invoice_lines` bilden die Faktentabelle.

                 ┌────────────────────────┐
                 │       customers        │
                 ├────────────────────────┤
                 │ customerid  (PK)       │
                 │ country                │
                 └─────────────┬──────────┘
                               │ 1
                               │
                               │ n
                 ┌─────────────▼──────────┐
                 │        invoices        │
                 ├────────────────────────┤
                 │ invoiceno     (PK)     │
                 │ customerid    (FK)     │
                 │ invoicedate            │
                 └─────────────┬──────────┘
                               │ 1
                               │
                               │ n
             ┌─────────────────▼────────────────┐
             │          invoice_lines           │
             ├──────────────────────────────────┤
             │ line_id         (PK)             │
             │ invoiceno       (FK)             │
             │ stockcode       (FK)             │
             │ quantity                         │
             │ unitprice                        │
             └──────────────────┬───────────────┘
                                │  n
                                │
                                │  1
                   ┌────────────▼───────────┐
                   │        products        │
                   ├────────────────────────┤
                   │ stockcode (PK)         │
                   │ description            │
                   └────────────────────────┘


                 ┌────────────────────────┐
                 │        dim_date        │
                 ├────────────────────────┤
                 │ date_key (PK)          │
                 │ year, month, day       │
                 │ weekday, week          │
                 │ quarter                │
                 └─────────────┬──────────┘
                               │
                               ▼
                         invoices.invoicedate::date






### 6. Validierung

Damit sicher ist, dass die neue Struktur korrekt ist, wurden mehrere Prüfungen durchgeführt.

Wichtige Ergebnisse:

- Anzahl Kunden in der neuen Tabelle = Anzahl verschiedener Kunden in den Rohdaten
- Anzahl Produkte stimmt exakt überein
- Anzahl Rechnungen stimmt
- Kein Datensatz verweist auf nicht existierende Kunden oder Produkte
- Keine verwaisten Rechnungsnummern
- Alle Fremdschlüsselbeziehungen sind gültig

Kurz gesagt: **die Normalisierung ist 100 % korrekt.**

### 7. Analyse der Produktbeschreibungen

Während der Validierung wurde ein wichtiges Problem sichtbar:

Manche Produktcodes hatten mehrere verschiedene Beschreibungen. 

Beispiele bei einem einzigen Produkt:

- "BLUE POLKADOT GARDEN PARASOL"
- "damaged"
- "wet/rusty"
- "check"

Das passiert oft in echten Shops, wenn Lagerpersonal Hinweise reinschreibt.

Um diese Inkonsistenzen zu lösen, wurde eine neue Tabelle gebaut.


### 8. Bereinigte Produkttabelle

Die Tabelle `products_cleaned` enthält:

stockcode | master_description | alternative_descriptions[]

Vorgehen:

1. Für jeden Produktcode wurde gezählt, wie häufig jede Beschreibung vorkommt  
2. Die **häufigste Beschreibung** wurde zum *master_description*  
3. Alle anderen Varianten wanderten in ein Array *alternative_descriptions*  

Beispiel:

| stockcode | master | alternative |
|-----------|--------|-------------|
| 15058A    | BLUE POLKADOT GARDEN PARASOL | {wet/rusty,NULL} |

Damit sind Produkttexte sauber, aber gleichzeitig bleibt die Information erhalten.

### 9. Endergebnis der Datenbank

Die finale Struktur besteht aus:

| Tabelle           | Zweck                          |
|-------------------|--------------------------------|
| retail_raw_v2     | Rohdaten                       |
| customers         | Kundenstammdaten               |
| products          | Produktstammdaten              |
| invoices          | Rechnungen                     |
| invoice_lines     | Positionen der Rechnung        |
| dim_date          | Datumstabelle                  |
| products_cleaned  | bereinigte Produktbeschreibung |

Diese Struktur entspricht echten Data-Engineering-Standards und eignet sich ideal für Reporting, BI oder Data Warehousing.



### 10. Projektstruktur im Repository

```pgsql
retail-lab/
│
├── docker-compose.yml
├── retail.csv
├── README.md
│
├── sql/
│   ├── cleaning/
│   │   ├── clean_customerid.sql
│   │   └── clean_descriptions.sql
│   │
│   ├── modeling/
│   │   └── 02_modeling_core.sql
│   │
│   ├── enrichment/
│   │   └── 03_products_cleaned.sql
│   │
│   └── validation/
│       └── 04_validation.sql
│
└── docs/
    └── validation-screenshots/
```

