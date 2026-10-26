"""Izvozi tabele iz SQLite baze u CSV fajlove za uvoz u SQL Server (BULK INSERT, UTF-8, CRLF).

Pokretanje iz korijena repozitorija:  python src/02_export_for_mssql.py
Izlaz: data/mssql_csv/*.csv  (zatim pokrenuti sql/mssql/00_schema.sql i 01_import_data.sql)
"""
import csv, pathlib, sqlite3
import pandas as pd

OUT = pathlib.Path("data/mssql_csv"); OUT.mkdir(parents=True, exist_ok=True)
con = sqlite3.connect("db/retail.db")
TABLES = {
    "trgovac": ["trgovac_id", "naziv", "tip"],
    "format_prodavnice": ["format_id", "trgovac_id", "naziv"],
    "kategorija": ["kategorija_id", "naziv"],
    "proizvod": ["barkod", "naziv", "robna_marka", "kategorija_id"],
    "cjenovnik": ["cjenovnik_id", "trgovac_id", "datum", "vrsta"],
    "cijena": ["cijena_id", "format_id", "cjenovnik_id", "barkod", "jedinica", "jedinica_grupa", "redovna_cijena",
               "cijena_po_jedinici", "snizena_cijena", "pocetak_snizenja", "kraj_snizenja", "pdv"],
    "kvalitet_log": ["stavka", "trgovac", "broj", "odluka"],
}
INT = {"trgovac_id", "format_id", "kategorija_id", "cjenovnik_id", "cijena_id", "pdv", "broj"}
for t, cols in TABLES.items():
    d = pd.read_sql(f"SELECT {', '.join(cols)} FROM {t}", con)
    for c in cols:
        if c in INT: d[c] = d[c].astype("Int64")
    d.to_csv(OUT / f"{t}.csv", index=False, encoding="utf-8", lineterminator="\r\n", quoting=csv.QUOTE_MINIMAL, float_format="%.2f")
    print(f"{t:18s} {len(d):>8,} redova")
