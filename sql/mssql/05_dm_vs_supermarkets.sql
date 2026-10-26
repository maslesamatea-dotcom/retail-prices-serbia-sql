/* ============================================================
   06 dm NASPRAM SUPERMARKETA (SQL Server)
   Pitanje: da li je ISTI proizvod (isti barkod) jeftiniji u dm-u ili u supermarketima?
   Poredimo samo proizvode koje prodaju i dm i bar jedan supermarket,
   u kategorijama gdje se oni zaista preklapaju.

   Preduslov: pogled dbo.v_cijene_glavni_format (pravi se u fajlu 03_chain_comparison.sql, Korak 0).
   Pokreni redom, jedan po jedan blok (označi pa Execute).
   ============================================================ */

/* ------------------------------------------------------------
   KORAK 0: pogled sa važećim dm cjenovnikom (jedan red po proizvodu)
   ------------------------------------------------------------ */
GO
CREATE OR ALTER VIEW dbo.v_dm_vazeci AS
SELECT c.barkod, c.redovna_cijena AS cijena
FROM dbo.cijena c
JOIN dbo.cjenovnik cj ON cj.cjenovnik_id = c.cjenovnik_id
JOIN dbo.trgovac t    ON t.trgovac_id = cj.trgovac_id
WHERE t.naziv = 'dm' AND cj.vrsta = 'VAZECI';
GO

-- Provjera: koliko dm proizvoda ima u važećem cjenovniku (očekivano 16057)
SELECT COUNT(*) AS dm_proizvoda FROM dbo.v_dm_vazeci;


/* ------------------------------------------------------------
   Q13. Gdje se dm preklapa sa supermarketima?   (EXISTS)
   EXISTS (podupit) je "da li postoji bar jedan red?". Za svaki dm proizvod pitamo:
   postoji li isti barkod u pogledu sa supermarketima? Ne važi koliko puta, samo da li postoji.
   ------------------------------------------------------------ */
SELECT k.naziv AS kategorija, COUNT(*) AS zajednickih_proizvoda
FROM dbo.v_dm_vazeci d
JOIN dbo.proizvod p   ON p.barkod = d.barkod
JOIN dbo.kategorija k ON k.kategorija_id = p.kategorija_id
WHERE EXISTS (SELECT 1 FROM dbo.v_cijene_glavni_format s WHERE s.barkod = d.barkod)
GROUP BY k.naziv
ORDER BY zajednickih_proizvoda DESC;


/* ------------------------------------------------------------
   Q14. dm naspram NAJJEFTINIJEG supermarketa, po kategorijama
   CTE `sm` svakom barkodu dodijeli najnižu cijenu među supermarketima.
   Zatim spojimo dm sa tim CTE-om i brojimo ko je jeftiniji.
   Strogi test: dm mora biti jeftiniji čak i od NAJJEFTINIJEG supermarketa.
   HAVING COUNT(*) >= 30 izbacuje kategorije sa premalo proizvoda.
   ------------------------------------------------------------ */
WITH sm AS (
    SELECT barkod, MIN(redovna_cijena) AS min_super
    FROM dbo.v_cijene_glavni_format
    GROUP BY barkod
)
SELECT k.naziv AS kategorija,
       COUNT(*) AS proizvoda,
       SUM(CASE WHEN d.cijena <  sm.min_super THEN 1 ELSE 0 END) AS dm_jeftiniji,
       SUM(CASE WHEN d.cijena >  sm.min_super THEN 1 ELSE 0 END) AS dm_skuplji,
       SUM(CASE WHEN d.cijena =  sm.min_super THEN 1 ELSE 0 END) AS isto,
       ROUND(AVG(100.0 * (d.cijena / sm.min_super - 1)), 1)     AS prosj_razlika_pct
FROM dbo.v_dm_vazeci d
JOIN sm                ON sm.barkod = d.barkod
JOIN dbo.proizvod p    ON p.barkod = d.barkod
JOIN dbo.kategorija k  ON k.kategorija_id = p.kategorija_id
GROUP BY k.naziv
HAVING COUNT(*) >= 30
ORDER BY prosj_razlika_pct;


/* ------------------------------------------------------------
   Q15. Ukupan rezultat (sve zajedničke kategorije)
   ------------------------------------------------------------ */
WITH sm AS (
    SELECT barkod, MIN(redovna_cijena) AS min_super
    FROM dbo.v_cijene_glavni_format
    GROUP BY barkod
)
SELECT COUNT(*) AS proizvoda,
       SUM(CASE WHEN d.cijena < sm.min_super THEN 1 ELSE 0 END) AS dm_jeftiniji,
       SUM(CASE WHEN d.cijena > sm.min_super THEN 1 ELSE 0 END) AS dm_skuplji,
       SUM(CASE WHEN d.cijena = sm.min_super THEN 1 ELSE 0 END) AS isto,
       ROUND(100.0 * SUM(CASE WHEN d.cijena < sm.min_super THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_dm_jeftiniji
FROM dbo.v_dm_vazeci d
JOIN sm ON sm.barkod = d.barkod;
