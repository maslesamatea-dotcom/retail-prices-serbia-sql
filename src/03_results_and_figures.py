"""Pokreće analitičke upite (isti kao u sql/mssql/, prevedeni u SQLite) i pravi tabele i grafike.

Pokretanje iz korijena repozitorija:  python src/03_results_and_figures.py
Izlaz: results/*.csv i results/*.png
"""
import sqlite3
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False, "figure.dpi": 130})
BLUE, ORANGE, RED, GRAY = "#5b6ee1", "#e8681a", "#d6453d", "#9aa1b1"
con = sqlite3.connect("db/retail.db")
con.executescript("""
DROP VIEW IF EXISTS v_cijene_glavni_format; DROP VIEW IF EXISTS v_cijene_vrijeme; DROP VIEW IF EXISTS v_dm_vazeci;
CREATE VIEW v_cijene_glavni_format AS
SELECT t.naziv AS trgovac, c.barkod, c.redovna_cijena, c.snizena_cijena,
       COALESCE(c.snizena_cijena, c.redovna_cijena) AS efektivna_cijena
FROM cijena c JOIN format_prodavnice f ON f.format_id = c.format_id JOIN trgovac t ON t.trgovac_id = f.trgovac_id
JOIN cjenovnik cj ON cj.cjenovnik_id = c.cjenovnik_id
WHERE cj.vrsta = 'VAZECI' AND t.tip = 'supermarket' AND f.naziv IN ('Mega Maxi', 'IDEA', 'UNIVEREXPORT - M');
CREATE VIEW v_cijene_vrijeme AS
SELECT t.naziv AS trgovac, t.tip, cj.datum, c.barkod, c.redovna_cijena
FROM cijena c JOIN format_prodavnice f ON f.format_id = c.format_id JOIN trgovac t ON t.trgovac_id = f.trgovac_id
JOIN cjenovnik cj ON cj.cjenovnik_id = c.cjenovnik_id
WHERE f.naziv IN ('Mega Maxi', 'IDEA', 'UNIVEREXPORT - M', 'dm drogerie markt');
CREATE VIEW v_dm_vazeci AS
SELECT c.barkod, c.redovna_cijena AS cijena FROM cijena c JOIN cjenovnik cj ON cj.cjenovnik_id = c.cjenovnik_id
JOIN trgovac t ON t.trgovac_id = cj.trgovac_id WHERE t.naziv = 'dm' AND cj.vrsta = 'VAZECI';
""")
q = lambda s: pd.read_sql(s, con)

# Q5: proizvodi po broju lanaca
r1 = q("""SELECT broj_lanaca, COUNT(*) AS broj_proizvoda FROM (SELECT barkod, COUNT(*) AS broj_lanaca
          FROM v_cijene_glavni_format GROUP BY barkod) x GROUP BY broj_lanaca ORDER BY broj_lanaca""")
r1.to_csv("results/r01_proizvodi_po_broju_lanaca.csv", index=False)

# Q7 + Q8: najjeftiniji lanac i koliko su ostali skuplji (samo proizvodi u sva 3 lanca)
p = q("""SELECT trgovac, barkod, redovna_cijena,
         RANK() OVER (PARTITION BY barkod ORDER BY redovna_cijena) AS mjesto,
         MIN(redovna_cijena) OVER (PARTITION BY barkod) AS najjeftinija,
         COUNT(*) OVER (PARTITION BY barkod) AS broj_lanaca FROM v_cijene_glavni_format""")
p = p[p.broj_lanaca == 3].copy(); p["pct_skuplje"] = 100 * (p.redovna_cijena / p.najjeftinija - 1)
r2 = p.groupby("trgovac").agg(proizvoda=("barkod", "count"), najjeftiniji=("mjesto", lambda s: int((s == 1).sum())),
                              prosj_pct_skuplje=("pct_skuplje", "mean"), medijana_pct_skuplje=("pct_skuplje", "median")).reset_index()
r2["udio_najjeftiniji_pct"] = (100 * r2.najjeftiniji / r2.proizvoda).round(1)
r2[["prosj_pct_skuplje", "medijana_pct_skuplje"]] = r2[["prosj_pct_skuplje", "medijana_pct_skuplje"]].round(1)
r2 = r2.sort_values("udio_najjeftiniji_pct", ascending=False); r2.to_csv("results/r02_najjeftiniji_lanac.csv", index=False)
izjednaceno = int((p[p.mjesto == 1].groupby("barkod").size() > 1).sum())

# Q9: promjena između uzastopnih cjenovnika
r3 = q("""WITH promjene AS (SELECT trgovac, barkod, datum, redovna_cijena,
   LAG(redovna_cijena) OVER (PARTITION BY trgovac, barkod ORDER BY datum) AS prethodna,
   LAG(datum) OVER (PARTITION BY trgovac, barkod ORDER BY datum) AS prethodni_datum FROM v_cijene_vrijeme)
 SELECT trgovac, prethodni_datum AS od_datuma, datum AS do_datuma, COUNT(*) AS proizvoda,
   SUM(CASE WHEN redovna_cijena > prethodna THEN 1 ELSE 0 END) AS poskupilo,
   SUM(CASE WHEN redovna_cijena < prethodna THEN 1 ELSE 0 END) AS pojeftinilo,
   ROUND(100.0*SUM(CASE WHEN redovna_cijena <> prethodna THEN 1 ELSE 0 END)/COUNT(*),1) AS udio_promijenjenih_pct
 FROM promjene WHERE prethodna IS NOT NULL GROUP BY trgovac, prethodni_datum, datum HAVING COUNT(*) > 100
 ORDER BY trgovac, datum""")
r3.to_csv("results/r03_promjena_cijena_po_koracima.csv", index=False)

# Q10 + Q11: ukupna promjena prvi -> zadnji cjenovnik; po kategorijama (samo supermarketi)
base = """WITH r AS (SELECT trgovac, tip, barkod, datum, redovna_cijena,
   ROW_NUMBER() OVER (PARTITION BY trgovac, barkod ORDER BY datum ASC) AS rn_prvi,
   ROW_NUMBER() OVER (PARTITION BY trgovac, barkod ORDER BY datum DESC) AS rn_zadnji FROM v_cijene_vrijeme),
 promjena AS (SELECT p.trgovac, p.tip, p.barkod, 100.0*(z.redovna_cijena/p.redovna_cijena-1) AS promjena_pct
   FROM r p JOIN r z ON z.trgovac = p.trgovac AND z.barkod = p.barkod AND z.rn_zadnji = 1
   WHERE p.rn_prvi = 1 AND p.datum <> z.datum) """
r4 = q(base + """SELECT trgovac, COUNT(*) AS proizvoda, SUM(CASE WHEN promjena_pct <> 0 THEN 1 ELSE 0 END) AS promijenjeno,
   SUM(CASE WHEN promjena_pct > 0 THEN 1 ELSE 0 END) AS poskupilo, SUM(CASE WHEN promjena_pct < 0 THEN 1 ELSE 0 END) AS pojeftinilo,
   ROUND(AVG(CASE WHEN promjena_pct <> 0 THEN promjena_pct END),1) AS prosj_promjena_promijenjenih_pct
   FROM promjena GROUP BY trgovac ORDER BY trgovac""")
r4["udio_promijenjenih_pct"] = (100 * r4.promijenjeno / r4.proizvoda).round(1); r4.to_csv("results/r04_promjena_cijena_ukupno.csv", index=False)
r5 = q(base + """SELECT k.naziv AS kategorija, COUNT(*) AS proizvoda,
   ROUND(100.0*SUM(CASE WHEN pr.promjena_pct > 0 THEN 1 ELSE 0 END)/COUNT(*),1) AS udio_poskupilih_pct,
   ROUND(AVG(pr.promjena_pct),2) AS prosj_promjena_pct
   FROM promjena pr JOIN proizvod p ON p.barkod = pr.barkod JOIN kategorija k ON k.kategorija_id = p.kategorija_id
   WHERE pr.tip = 'supermarket' GROUP BY k.naziv HAVING COUNT(*) >= 300 ORDER BY prosj_promjena_pct DESC""")
r5.to_csv("results/r05_promjena_po_kategorijama_supermarketi.csv", index=False)

# Q14 + Q15: dm naspram najjeftinijeg supermarketa
sm = "WITH sm AS (SELECT barkod, MIN(redovna_cijena) AS min_super FROM v_cijene_glavni_format GROUP BY barkod) "
r6 = q(sm + """SELECT k.naziv AS kategorija, COUNT(*) AS proizvoda,
   SUM(CASE WHEN d.cijena < sm.min_super THEN 1 ELSE 0 END) AS dm_jeftiniji, SUM(CASE WHEN d.cijena > sm.min_super THEN 1 ELSE 0 END) AS dm_skuplji,
   SUM(CASE WHEN d.cijena = sm.min_super THEN 1 ELSE 0 END) AS isto, ROUND(AVG(100.0*(d.cijena/sm.min_super-1)),1) AS prosj_razlika_pct
   FROM v_dm_vazeci d JOIN sm ON sm.barkod = d.barkod JOIN proizvod p ON p.barkod = d.barkod JOIN kategorija k ON k.kategorija_id = p.kategorija_id
   GROUP BY k.naziv HAVING COUNT(*) >= 30 ORDER BY prosj_razlika_pct""")
r6.to_csv("results/r06_dm_naspram_supermarketa_kategorije.csv", index=False)
tot = q(sm + """SELECT COUNT(*) AS proizvoda, SUM(CASE WHEN d.cijena < sm.min_super THEN 1 ELSE 0 END) AS dm_jeftiniji,
   SUM(CASE WHEN d.cijena > sm.min_super THEN 1 ELSE 0 END) AS dm_skuplji, SUM(CASE WHEN d.cijena = sm.min_super THEN 1 ELSE 0 END) AS isto
   FROM v_dm_vazeci d JOIN sm ON sm.barkod = d.barkod""").iloc[0]
tot["pct_dm_jeftiniji"] = round(100 * tot.dm_jeftiniji / tot.proizvoda, 1)
pd.DataFrame([tot]).to_csv("results/r07_dm_naspram_supermarketa_ukupno.csv", index=False)
odnos = q(sm + "SELECT d.cijena/sm.min_super AS o FROM v_dm_vazeci d JOIN sm ON sm.barkod = d.barkod").o.median()

# ------------------------------------------------------------------ grafici
fig, ax = plt.subplots(figsize=(6.5, 3.6)); ax.bar(r1.broj_lanaca.astype(str), r1.broj_proizvoda, color=BLUE, alpha=.88)
for i, v in enumerate(r1.broj_proizvoda): ax.text(i, v + 250, f"{v:,}".replace(",", "."), ha="center")
ax.set_xlabel("u koliko od tri supermarketa se proizvod prodaje"); ax.set_ylabel("broj proizvoda (barkodova)")
ax.set_title("Većina proizvoda je u samo jednom lancu"); fig.tight_layout(); fig.savefig("results/01_proizvodi_po_broju_lanaca.png"); plt.close()

fig, ax = plt.subplots(1, 2, figsize=(10, 3.8)); o = r2.sort_values("udio_najjeftiniji_pct")
ax[0].barh(o.trgovac, o.udio_najjeftiniji_pct, color=BLUE, alpha=.88)
for i, v in enumerate(o.udio_najjeftiniji_pct): ax[0].text(v + .5, i, f"{v}%", va="center")
ax[0].set_title("Udio proizvoda sa najnižom cijenom"); ax[0].set_xlabel("% (zbir > 100%: izjednačene cijene)")
o = r2.sort_values("medijana_pct_skuplje", ascending=False)
ax[1].barh(o.trgovac, o.medijana_pct_skuplje, color=ORANGE, alpha=.88)
for i, v in enumerate(o.medijana_pct_skuplje): ax[1].text(v + .1, i, f"{v}%", va="center")
ax[1].set_title("Medijana: za koliko % skuplji od najjeftinijeg"); ax[1].set_xlabel("%")
fig.suptitle(f"Isti proizvod u sva tri supermarketa (n = {int(r2.proizvoda.iloc[0]):,})".replace(",", "."), fontsize=10)
fig.tight_layout(); fig.savefig("results/02_najjeftiniji_lanac.png"); plt.close()

g = r3.copy(); g["korak"] = g.trgovac + "\n" + g.od_datuma.str[8:10] + "." + g.od_datuma.str[5:7] + ". → " + g.do_datuma.str[8:10] + "." + g.do_datuma.str[5:7] + "."
g["poskupilo_pct"] = 100 * g.poskupilo / g.proizvoda; g["pojeftinilo_pct"] = 100 * g.pojeftinilo / g.proizvoda
fig, ax = plt.subplots(figsize=(7.5, 4.6)); y = np.arange(len(g))[::-1]
ax.barh(y, g.poskupilo_pct, color=RED, alpha=.85, label="poskupilo"); ax.barh(y, -g.pojeftinilo_pct, color=BLUE, alpha=.85, label="pojeftinilo")
ax.set_yticks(y); ax.set_yticklabels(g.korak, fontsize=8); ax.axvline(0, color="black", lw=.6); ax.legend(frameon=False, loc="lower right")
ax.set_xlabel("% proizvoda sa promijenjenom redovnom cijenom"); ax.set_title("Promjena cijena između uzastopnih cjenovnika"); fig.tight_layout()
fig.savefig("results/03_promjena_cijena_po_koracima.png"); plt.close()

h = r6.sort_values("prosj_razlika_pct", ascending=False)
fig, ax = plt.subplots(figsize=(8, 4.4)); ax.barh(h.kategorija.str[:42], h.prosj_razlika_pct, color=BLUE, alpha=.88)
for i, (v, n) in enumerate(zip(h.prosj_razlika_pct, h.proizvoda)): ax.text(v - .3, i, f"{v}%  (n={n})", va="center", ha="right", fontsize=8)
ax.set_xlabel("prosječna razlika dm cijene u odnosu na najjeftiniji supermarket (%)"); ax.set_title("dm je jeftiniji na zajedničkim proizvodima")
ax.set_xlim(h.prosj_razlika_pct.min() - 9, 1); fig.tight_layout(); fig.savefig("results/04_dm_naspram_supermarketa.png"); plt.close()

pd.Series({"izjednaceno_najnize": izjednaceno, "medijana_dm_odnos": round(float(odnos), 3)}).to_csv("results/meta.csv", header=False)
print("gotovo: rezultati i grafici sačuvani u results/")
print(r2.to_string(index=False)); print(tot.to_string())
