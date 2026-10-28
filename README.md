# Prices in Serbian Retail Chains: SQL Analysis of Open Data

**Language:** English | [Srpski](README.sr.md)

Author: Matea Masleša

This project analyses the price lists of four retail chains in Serbia (Delhaize/Maxi, IDEA, Univerexport and dm), which retailers are required to publish as open data. The data were cleaned, loaded into a relational database with several linked tables and analysed with SQL: comparing prices of identical products across chains, price changes over time, and comparing a drugstore (dm) with supermarkets.

## Data

- **Source:** open data portal (data.gov.rs), the datasets *Price lists of products according to the Rulebook on the conditions, content and manner of publishing price lists* (original title in Serbian: *Cjenovnici proizvoda prema Pravilniku o uslovima, sadržaju i načinu objavljivanja cjenovnika*), one per retailer. Links are in [`data/README.md`](data/README.md).
- **Licence:** Serbian Open Data Licence (the source and download date must be stated). Downloaded on 23 October 2026.
- **Size:** 457,348 rows, 15 columns in all four files, three price lists per retailer: monthly snapshots from 1 Sep and 1 Oct 2026 and the current price list (20 and 23 Oct 2026).
- The raw data are **not in the repository**; the scripts load them from `data/raw/`.

## Database

Star schema: dimensions and one fact table. (Table and column names are in Serbian.)

| Table | Content |
|---|---|
| `trgovac` | 4 retailers and their type (supermarket or drugstore) |
| `format_prodavnice` | 12 store formats (Maxi, Mega Maxi, MERCATOR, RODA...) |
| `kategorija` | the shared list of 25 categories |
| `proizvod` | one row per barcode (the shared key across chains) |
| `cjenovnik` | retailer + date + type of price list |
| `cijena` | fact table: price per format, price list and product |
| `kvalitet_log` | log of cleaning decisions |

## Data cleaning

457,348 rows were loaded and 456,538 remain in the database. All decisions are recorded in the table `kvalitet_log`:

| Issue | Retailer | Rows | Decision |
|---|---|---|---|
| barcode in several categories | all | 519 | most frequent category used |
| duplicate with different prices | Univerexport | 33 | removed (we cannot know which is correct) |
| unknown unit of measure | dm | 6 | group stays NULL |
| exact duplicate | Delhaize | 12 | one row kept |
| row without barcode | Delhaize | 15 | removed (product cannot be linked) |
| regular price empty or 0 | Delhaize | 3 | removed (no meaningful price) |
| regular price empty or 0 | Univerexport | 747 | removed (no meaningful price) |
| discounted price = 0 | Univerexport | 131,007 | converted to NULL (no discount) |
| discounted price >= regular | IDEA | 109 | converted to NULL (data error) |
| discounted price >= regular | dm | 2 | converted to NULL (data error) |

In addition, units of measure (kg, KG, lit, L, kom, 1kom, 100ml...) were grouped (mass, volume, piece, length), keeping the original value.

## Methodological decisions

- **Store format changes the price.** Maxi, Maxi Online and Mega Maxi have almost identical prices (under 1% difference), while Profi (about 5% cheaper) and Shop and Go (about 4% more expensive) deviate. Therefore **one standard format** per chain is compared: Mega Maxi, IDEA and UNIVEREXPORT - M (the middle format by price level).
- **dm is a drugstore.** 76% of its range is personal hygiene and cosmetics, and only 25% of its products also exist in some supermarket. So **supermarkets are compared with each other across all categories, while dm is compared separately**, only on shared products.
- Comparison is done **by barcode** (same product, same package) and on the **regular price**.

## Results

### Which products can be compared
Of 31,146 products across the three supermarkets, **5,267** are sold in all three, 6,403 in two and 19,476 in only one.

![products](results/01_proizvodi_po_broju_lanaca.png)

### Who is cheapest (only products sold in all three supermarkets)
For the 5,267 shared products: **Delhaize** had the lowest price for 47.8% of products, Univerexport for 35.7% and IDEA for 32.2%. The shares add up to more than 100% because for 724 products the lowest price is tied between two chains. Differences are small: the median is 0.4% (Delhaize), 3.0% (Univerexport) and 3.8% (IDEA) above the lowest price.

![cheapest](results/02_najjeftiniji_lanac.png)

### Price changes over time
| Retailer | Period | Products | Increased | Decreased | Changed |
|---|---|---|---|---|---|
| Delhaize | 1 Sep → 1 Oct | 10,899 | 1,065 | 109 | 10.8% |
| Delhaize | 1 Oct → 23 Oct | 10,972 | 568 | 99 | 6.1% |
| IDEA | 1 Sep → 1 Oct | 19,540 | 1,379 | 140 | 7.8% |
| IDEA | 1 Oct → 23 Oct | 20,076 | 579 | 153 | 3.6% |
| Univerexport | 1 Sep → 1 Oct | 16,279 | 1,189 | 1,397 | 15.9% |
| Univerexport | 1 Oct → 23 Oct | 16,239 | 830 | 587 | 8.7% |
| dm | 1 Sep → 1 Oct | 15,030 | 754 | 1,688 | 16.2% |
| dm | 1 Oct → 20 Oct | 15,142 | 60 | 24 | 0.6% |

Total change from the first to the last price list:

| Retailer | Products | Changed | Increased | Decreased | Mean change among changed |
|---|---|---|---|---|---|
| Delhaize | 11,059 | 16.0% | 1,582 | 183 | 5.1% |
| IDEA | 20,076 | 10.5% | 1,885 | 224 | 7.4% |
| Univerexport | 16,498 | 22.5% | 1,908 | 1,812 | -0.4% |
| dm | 15,285 | 16.4% | 798 | 1,707 | -4.7% |

![changes](results/03_promjena_cijena_po_koracima.png)

Delhaize and IDEA mostly raised prices, dm mostly lowered them (almost all between 1 Sep and 1 Oct), and Univerexport had about as many increases as decreases. Among supermarket categories the largest increase was in "Flour, baking ingredients and powdered products" (on average 2.33%), and the only category with a slight decrease was "Fresh and processed fish" (-0.51%). A review of extreme changes shows that some of the "jumps" are probably not price increases (e.g. "DINJA", a melon, from 79.99 to 259.99, probably a seasonal price or a change in how it is weighed), so results must be read with care.

### dm vs supermarkets
For 3,903 products sold by both dm and at least one supermarket, dm has a **lower regular price than the cheapest supermarket for 76.0%** of products (higher for 23.6%). The median ratio of the dm price to the cheapest supermarket price is 0.888.

| Category | Products | dm cheaper | Mean difference |
|---|---|---|---|
| Diapers | 46 | 46 | -21.1% |
| Paper and kitchen goods | 194 | 160 | -15.2% |
| Household chemicals | 544 | 425 | -12.3% |
| Pet food | 59 | 55 | -11.5% |
| Baby food | 199 | 152 | -9.6% |
| Personal hygiene and cosmetics | 2,383 | 1,802 | -9.6% |
| Soft drinks, coffee, tea | 93 | 68 | -8.1% |
| Processed fruit and vegetables and spreads | 67 | 55 | -8.1% |
| Sweets and cereals | 177 | 113 | -4.0% |

![dm](results/04_dm_naspram_supermarketa.png)

## Limitations

- The data cover **about seven weeks** (three price lists), so no conclusions about long-term trends can be drawn.
- Only **one format per chain** and the **regular price** are compared (without discounts and without sales weights). The result is a comparison of **shared products**, not of a shopping basket, so it cannot be said which chain is "cheapest" overall.
- Prices are at store-format level, not for individual stores, so cities cannot be compared.
- Shared products are probably the more popular brands, which may affect the comparison with dm.
- Obvious data errors were handled (zeros, duplicates), but suspicious prices (e.g. 107,565 RSD for a single detergent) were not corrected by hand.
- Names, units and categories come from the retailers and are not fully consistent.

## SQL techniques used

`JOIN` (including a self join), `GROUP BY` and `HAVING`, subqueries and `EXISTS`, CTEs (`WITH`), views, conditional aggregation (`CASE WHEN`), window functions (`RANK`, `ROW_NUMBER`, `LAG`, `MIN() OVER`), data cleaning and star-schema design.

## Structure and usage

```
data/        instructions for downloading the data (raw files are not published)
sql/mssql/   T-SQL: schema, data import and analytical queries (SQL Server)
sql/sqlite/  SQLite schema (used by Python)
src/         Python scripts (cleaning and building the database, export, figures)
results/     tables (csv) and figures (png)
```

**Option A: SQL Server (SSMS).** The queries in `sql/mssql/` are written in T-SQL. Comments in the SQL files are in Serbian.
1. Download the data into `data/raw/` (see `data/README.md`), run `python src/01_build_sqlite_db.py` and then `python src/02_export_for_mssql.py` (creates CSV files in `data/mssql_csv/`).
2. In SSMS create a database (`CREATE DATABASE retail;`), then run `00_schema.sql` and `01_import_data.sql` in order (change the path in the first line first), followed by `02_basics.sql` through `05_dm_vs_supermarkets.sql`.

**Option B: Python + SQLite.**
```bash
pip install -r requirements.txt
python src/01_build_sqlite_db.py      # cleaning and database db/retail.db
python src/03_results_and_figures.py  # tables and figures in results/
```
Run the scripts from the repository root.
