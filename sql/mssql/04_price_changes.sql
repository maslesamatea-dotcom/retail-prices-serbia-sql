/* ============================================================
   05 PROMJENA CIJENA KROZ VRIJEME (SQL Server)
   Imamo tri cjenovnika po trgovcu: 1.9., 1.10. i trenutni (20/23.10.2026).
   Pitanje: koliko se cijene mijenjaju, kod koga i u kojim kategorijama?

   Pokreni redom, jedan po jedan blok (označi pa Execute).
   ============================================================ */

/* ------------------------------------------------------------
   KORAK 0: POGLED sa svim cjenovnicima, po jedan format po lancu
   (isti formati kao ranije; dm ima samo jedan format).
   ------------------------------------------------------------ */
GO
CREATE OR ALTER VIEW dbo.v_cijene_vrijeme AS
SELECT t.naziv AS trgovac, t.tip, cj.datum, c.barkod, c.redovna_cijena
FROM dbo.cijena c
JOIN dbo.format_prodavnice f ON f.format_id = c.format_id
JOIN dbo.trgovac t           ON t.trgovac_id = f.trgovac_id
JOIN dbo.cjenovnik cj        ON cj.cjenovnik_id = c.cjenovnik_id
WHERE f.naziv IN ('Mega Maxi', 'IDEA', 'UNIVEREXPORT - M', 'dm drogerie markt');
GO

-- Provjera: redova po trgovcu i datumu (po 3 cjenovnika za svakog)
SELECT trgovac, datum, COUNT(*) AS redova
FROM dbo.v_cijene_vrijeme
GROUP BY trgovac, datum
ORDER BY trgovac, datum;


/* ------------------------------------------------------------
   Q9. Koliko se cijena mijenja između dva uzastopna cjenovnika?   (LAG)
   LAG(cijena) OVER (PARTITION BY trgovac, barkod ORDER BY datum) svakom redu doda
   cijenu iz PRETHODNOG cjenovnika istog proizvoda kod istog trgovca.
   Prvi cjenovnik nema prethodni (NULL), pa te redove izbacujemo.
   HAVING COUNT(*) > 100 uklanja sitne grupe (proizvodi koji su preskočili cjenovnik).
   ------------------------------------------------------------ */
WITH promjene AS (
    SELECT trgovac, barkod, datum, redovna_cijena,
           LAG(redovna_cijena) OVER (PARTITION BY trgovac, barkod ORDER BY datum) AS prethodna,
           LAG(datum)          OVER (PARTITION BY trgovac, barkod ORDER BY datum) AS prethodni_datum
    FROM dbo.v_cijene_vrijeme
)
SELECT trgovac, prethodni_datum AS od_datuma, datum AS do_datuma,
       COUNT(*) AS proizvoda,
       SUM(CASE WHEN redovna_cijena > prethodna THEN 1 ELSE 0 END) AS poskupilo,
       SUM(CASE WHEN redovna_cijena < prethodna THEN 1 ELSE 0 END) AS pojeftinilo,
       ROUND(100.0 * SUM(CASE WHEN redovna_cijena <> prethodna THEN 1 ELSE 0 END) / COUNT(*), 1) AS udio_promijenjenih_pct
FROM promjene
WHERE prethodna IS NOT NULL
GROUP BY trgovac, prethodni_datum, datum
HAVING COUNT(*) > 100
ORDER BY trgovac, datum;


/* ------------------------------------------------------------
   Q10. Ukupna promjena od prvog do posljednjeg cjenovnika po trgovcu
   ROW_NUMBER() daje svakom proizvodu redni broj cjenovnika od početka (rn_prvi = 1 je prvi)
   i od kraja (rn_zadnji = 1 je posljednji). Zatim tabelu SPOJIMO SA SAMOM SOBOM
   (self join): lijeva strana p = prvi cjenovnik, desna strana z = posljednji.
   ------------------------------------------------------------ */
WITH r AS (
    SELECT trgovac, barkod, datum, redovna_cijena,
           ROW_NUMBER() OVER (PARTITION BY trgovac, barkod ORDER BY datum ASC)  AS rn_prvi,
           ROW_NUMBER() OVER (PARTITION BY trgovac, barkod ORDER BY datum DESC) AS rn_zadnji
    FROM dbo.v_cijene_vrijeme
),
promjena AS (
    SELECT p.trgovac, p.barkod,
           100.0 * (z.redovna_cijena / p.redovna_cijena - 1) AS promjena_pct
    FROM r p
    JOIN r z ON z.trgovac = p.trgovac AND z.barkod = p.barkod AND z.rn_zadnji = 1
    WHERE p.rn_prvi = 1 AND p.datum <> z.datum          -- proizvod mora imati bar 2 cjenovnika
)
SELECT trgovac,
       COUNT(*) AS proizvoda,
       SUM(CASE WHEN promjena_pct <> 0 THEN 1 ELSE 0 END) AS promijenjeno,
       SUM(CASE WHEN promjena_pct > 0  THEN 1 ELSE 0 END) AS poskupilo,
       SUM(CASE WHEN promjena_pct < 0  THEN 1 ELSE 0 END) AS pojeftinilo,
       ROUND(AVG(CASE WHEN promjena_pct <> 0 THEN promjena_pct END), 1) AS prosj_promjena_promijenjenih_pct
FROM promjena
GROUP BY trgovac
ORDER BY trgovac;


/* ------------------------------------------------------------
   Q11. Koje kategorije su najviše poskupjele? (samo supermarketi)
   Isti CTE kao u Q10, ali dodatno spojen sa proizvod i kategorija.
   dm je izuzet da ne iskrivi kategorije (kozmetika, higijena).
   ------------------------------------------------------------ */
WITH r AS (
    SELECT trgovac, tip, barkod, datum, redovna_cijena,
           ROW_NUMBER() OVER (PARTITION BY trgovac, barkod ORDER BY datum ASC)  AS rn_prvi,
           ROW_NUMBER() OVER (PARTITION BY trgovac, barkod ORDER BY datum DESC) AS rn_zadnji
    FROM dbo.v_cijene_vrijeme
),
pr AS (
    SELECT p.barkod, 100.0 * (z.redovna_cijena / p.redovna_cijena - 1) AS promjena_pct
    FROM r p
    JOIN r z ON z.trgovac = p.trgovac AND z.barkod = p.barkod AND z.rn_zadnji = 1
    WHERE p.rn_prvi = 1 AND p.datum <> z.datum AND p.tip = 'supermarket'
)
SELECT k.naziv AS kategorija,
       COUNT(*) AS proizvoda,
       ROUND(100.0 * SUM(CASE WHEN pr.promjena_pct > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS udio_poskupilih_pct,
       ROUND(AVG(pr.promjena_pct), 2) AS prosj_promjena_pct
FROM pr
JOIN dbo.proizvod p   ON p.barkod = pr.barkod
JOIN dbo.kategorija k ON k.kategorija_id = p.kategorija_id
GROUP BY k.naziv
HAVING COUNT(*) >= 300
ORDER BY prosj_promjena_pct DESC;


/* ------------------------------------------------------------
   Q12. PROVJERA PODATAKA: pet najvećih promjena cijene
   Uvijek pogledaj ekstreme. Skok sa 79,99 na 259,99 za isti barkod vjerovatno znači
   drugačije pakovanje ili grešku u unosu, a ne stvarno poskupljenje.
   ------------------------------------------------------------ */
WITH r AS (
    SELECT trgovac, barkod, datum, redovna_cijena,
           ROW_NUMBER() OVER (PARTITION BY trgovac, barkod ORDER BY datum ASC)  AS rn_prvi,
           ROW_NUMBER() OVER (PARTITION BY trgovac, barkod ORDER BY datum DESC) AS rn_zadnji
    FROM dbo.v_cijene_vrijeme
)
SELECT TOP 5 p.trgovac, pr.naziv, p.redovna_cijena AS prva, z.redovna_cijena AS zadnja,
       ROUND(100.0 * (z.redovna_cijena / p.redovna_cijena - 1), 1) AS promjena_pct
FROM r p
JOIN r z         ON z.trgovac = p.trgovac AND z.barkod = p.barkod AND z.rn_zadnji = 1
JOIN dbo.proizvod pr ON pr.barkod = p.barkod
WHERE p.rn_prvi = 1 AND p.datum <> z.datum
ORDER BY ABS(z.redovna_cijena / p.redovna_cijena - 1) DESC;
