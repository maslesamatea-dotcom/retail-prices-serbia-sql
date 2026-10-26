"""Učitava četiri CSV fajla cjenovnika u SQLite bazu uz čišćenje podataka.

Pokretanje iz korijena repozitorija:  python src/01_build_db.py
Očekuje fajlove u data/raw/ (nazivi su u rječniku FAJLOVI ispod). Izlaz: db/retail.db
"""
import sqlite3, pathlib
import pandas as pd

RAW = pathlib.Path("data/raw")
DB = pathlib.Path("db/retail.db")
FAJLOVI = {                                   # trgovac -> (fajl, tip trgovca)
    "Delhaize":     ("cene_proizvoda_Delhaize.csv", "supermarket"),
    "IDEA":         ("cene_proizvoda_ideamarketi.csv", "supermarket"),
    "Univerexport": ("univer.csv", "supermarket"),
    "dm":           ("cene-proizvoda-dmdrogeriemarkt-data.csv", "drogerija"),
}
log = []                                       # (stavka, trgovac, broj, odluka)

# ---------------------------------------------------------------- 1. učitavanje
frames = []
for trg, (f, tip) in FAJLOVI.items():
    d = pd.read_csv(RAW / f, sep=";", encoding="utf-8-sig", dtype=str, keep_default_na=False)
    d.columns = [c.strip() for c in d.columns]
    d["trgovac"] = trg
    frames.append(d)
    log.append(("učitano redova", trg, len(d), "sirovi podaci"))
df = pd.concat(frames, ignore_index=True)

# ---------------------------------------------------------------- 2. tipovi i formati
df = df.rename(columns={"KATEGORIJA": "kat", "NAZIV KATEGORIJE": "kat_naziv", "Naziv proizvoda": "naziv",
                        "Robna marka": "marka", "Barkod proizvoda": "barkod", "Jedinica mere": "jedinica",
                        "Naziv trgovca - formata": "format", "Datum cenovnika": "datum",
                        "Redovna cena": "redovna", "Cena po jedinici mere": "po_jedinici",
                        "Snižena cena": "snizena", "Datum početka sniženja": "sn_od",
                        "Datum kraja sniženja": "sn_do", "Stopa PDV": "pdv", "VRSTA_CENOVNIKA": "vrsta"})
for c in ("naziv", "marka", "barkod", "jedinica", "format"):
    df[c] = df[c].str.strip()
for c in ("redovna", "po_jedinici", "snizena"):
    df[c] = pd.to_numeric(df[c].str.replace(",", ".", regex=False), errors="coerce")
iso = lambda s: pd.to_datetime(s, format="%d-%m-%Y", errors="coerce").dt.strftime("%Y-%m-%d")
df["datum"], df["sn_od"], df["sn_do"] = iso(df["datum"]), iso(df["sn_od"]), iso(df["sn_do"])
df["vrsta"] = df["vrsta"].replace({"MESECNI_PRESEK": "MJESECNI_PRESJEK", "VAZECI_CENOVNIK": "VAZECI"})
df["kat"] = df["kat"].astype(int)
df["pdv"] = pd.to_numeric(df["pdv"], errors="coerce").astype("Int64")

# ---------------------------------------------------------------- 3. čišćenje
def ukloni(maska, stavka, odluka):
    global df
    for trg, n in df[maska].groupby("trgovac").size().items():
        log.append((stavka, trg, int(n), odluka))
    df = df[~maska]

ukloni(df["barkod"] == "", "red bez barkoda", "uklonjeno (proizvod se ne može povezati)")
ukloni(df["redovna"].isna() | (df["redovna"] <= 0), "redovna cijena prazna ili 0", "uklonjeno (nema smislene cijene)")

# duplikati po ključu (format, cjenovnik, barkod): ako su cijene iste, ostavi jedan red; ako su različite, ukloni oba
kljuc = ["trgovac", "format", "datum", "vrsta", "barkod"]
n_cij = df.groupby(kljuc)["redovna"].transform("nunique")
ukloni((n_cij > 1), "duplikat sa različitim cijenama", "uklonjeno (ne znamo koja je tačna)")
dup = df.duplicated(kljuc)
for trg, n in df[dup].groupby("trgovac").size().items():
    log.append(("potpuni duplikat", trg, int(n), "ostavljen jedan red"))
df = df[~dup]

# sniženja: 0 znači "nema sniženja" (Univerexport) -> NULL; sniženje >= redovne cijene je greška -> NULL
nula = df["snizena"] == 0
for trg, n in df[nula].groupby("trgovac").size().items():
    log.append(("snižena cijena = 0", trg, int(n), "pretvoreno u NULL (nema sniženja)"))
df.loc[nula, "snizena"] = pd.NA
greska = df["snizena"].notna() & (df["snizena"] >= df["redovna"])
for trg, n in df[greska].groupby("trgovac").size().items():
    log.append(("snižena cijena >= redovne", trg, int(n), "pretvoreno u NULL (greška u podacima)"))
df.loc[greska, ["snizena", "sn_od", "sn_do"]] = pd.NA
df.loc[df["snizena"].isna(), ["sn_od", "sn_do"]] = pd.NA

# jedinice mjere: ostavi izvornu (mala slova) i dodaj grupu
df["jedinica"] = df["jedinica"].str.lower()
GRUPE = {"kg": "masa", "g": "masa", "100g": "masa", "10g": "masa", "1kg": "masa", "1000g": "masa", "1g": "masa", "gram": "masa",
         "l": "zapremina", "lit": "zapremina", "1l": "zapremina", "100ml": "zapremina", "10ml": "zapremina", "1ml": "zapremina", "30ml": "zapremina",
         "kom": "komad", "1kom": "komad", "komad": "komad", "100kom": "komad", "12kom": "komad", "rln": "komad",
         "1m": "duzina", "centimetar": "duzina"}
df["jedinica_grupa"] = df["jedinica"].map(GRUPE)
for trg, n in df[df["jedinica_grupa"].isna()].groupby("trgovac").size().items():
    log.append(("nepoznata jedinica mjere", trg, int(n), "grupa ostaje NULL"))

# ---------------------------------------------------------------- 4. dimenzije
con = sqlite3.connect(DB) if DB.parent.exists() else None
DB.parent.mkdir(exist_ok=True)
if DB.exists(): DB.unlink()
con = sqlite3.connect(DB)
con.executescript(pathlib.Path("sql/sqlite/00_schema_sqlite.sql").read_text(encoding="utf-8"))

tr = pd.DataFrame([(i + 1, k, v[1]) for i, (k, v) in enumerate(FAJLOVI.items())], columns=["trgovac_id", "naziv", "tip"])
tr.to_sql("trgovac", con, if_exists="append", index=False)
tid = dict(zip(tr["naziv"], tr["trgovac_id"]))

fm = df[["trgovac", "format"]].drop_duplicates().reset_index(drop=True)
fm["format_id"] = fm.index + 1; fm["trgovac_id"] = fm["trgovac"].map(tid)
fm.rename(columns={"format": "naziv"})[["format_id", "trgovac_id", "naziv"]].to_sql("format_prodavnice", con, if_exists="append", index=False)
fid = {(r.trgovac, r.format): r.format_id for r in fm.itertuples()}

# kategorije: naziv iz Delhaizea (pisan malim slovima sa velikim početnim)
kt = df[df["trgovac"] == "Delhaize"][["kat", "kat_naziv"]].drop_duplicates("kat")
miss = set(df["kat"]) - set(kt["kat"])
kt = pd.concat([kt, df[df["kat"].isin(miss)][["kat", "kat_naziv"]].drop_duplicates("kat").assign(kat_naziv=lambda x: x["kat_naziv"].str.capitalize())])
kt.rename(columns={"kat": "kategorija_id", "kat_naziv": "naziv"}).to_sql("kategorija", con, if_exists="append", index=False)

# proizvod: najčešći naziv/marka/kategorija za barkod (isti barkod ima različite nazive među lancima)
def najcesci(s): return s.mode().iloc[0]
pr = df.groupby("barkod").agg(naziv=("naziv", najcesci), robna_marka=("marka", najcesci), kategorija_id=("kat", najcesci)).reset_index()
vise_kat = df.groupby("barkod")["kat"].nunique(); log.append(("barkod u više kategorija", "svi", int((vise_kat > 1).sum()), "uzeta najčešća kategorija"))
pr.to_sql("proizvod", con, if_exists="append", index=False)

cj = df[["trgovac", "datum", "vrsta"]].drop_duplicates().reset_index(drop=True)
cj["cjenovnik_id"] = cj.index + 1; cj["trgovac_id"] = cj["trgovac"].map(tid)
cj[["cjenovnik_id", "trgovac_id", "datum", "vrsta"]].to_sql("cjenovnik", con, if_exists="append", index=False)
cid = {(r.trgovac, r.datum, r.vrsta): r.cjenovnik_id for r in cj.itertuples()}

# ---------------------------------------------------------------- 5. tabela činjenica
f = pd.DataFrame({
    "format_id": [fid[(t, fo)] for t, fo in zip(df["trgovac"], df["format"])],
    "cjenovnik_id": [cid[(t, d, v)] for t, d, v in zip(df["trgovac"], df["datum"], df["vrsta"])],
    "barkod": df["barkod"].values, "jedinica": df["jedinica"].values, "jedinica_grupa": df["jedinica_grupa"].values,
    "redovna_cijena": df["redovna"].values, "cijena_po_jedinici": df["po_jedinici"].values,
    "snizena_cijena": df["snizena"].astype(float).values, "pocetak_snizenja": df["sn_od"].values,
    "kraj_snizenja": df["sn_do"].values, "pdv": df["pdv"].values})
f.to_sql("cijena", con, if_exists="append", index=False)
pd.DataFrame(log, columns=["stavka", "trgovac", "broj", "odluka"]).to_sql("kvalitet_log", con, if_exists="append", index=False)
con.commit()

for t in ("trgovac", "format_prodavnice", "kategorija", "proizvod", "cjenovnik", "cijena", "kvalitet_log"):
    print(f"{t:18s}", con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0])
con.close()
print("Baza sačuvana:", DB)
