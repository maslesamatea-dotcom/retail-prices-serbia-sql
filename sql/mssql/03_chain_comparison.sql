/* ============================================================
   03 POREĐENJE LANACA (SQL Server)
   Poredimo cijene ISTIH proizvoda (isti barkod) u tri supermarketa:
   Delhaize, IDEA i Univerexport. dm se poredi posebno, jer je drogerija.

   Pokreni redom, jedan po jedan blok (označi pa Execute).
   ============================================================ */

/* ------------------------------------------------------------
   KORAK 0: POGLED (VIEW) sa jednim standardnim formatom po lancu
   Zašto: isti proizvod ima više redova (formati prodavnica). Da ne poredimo
   "jabuke i kruške", biramo po jedan format:
     Delhaize     -> Mega Maxi   (Maxi, Maxi Online i Mega Maxi imaju gotovo iste cijene)
     IDEA         -> IDEA
     Univerexport -> UNIVEREXPORT - M (srednji format po nivou cijena)
   Pogled je "snimljen upit": poslije ga koristimo kao običnu tabelu.
   CREATE OR ALTER VIEW mora biti prva naredba u bloku, zato je između GO.
   ------------------------------------------------------------ */
GO
CREATE OR ALTER VIEW dbo.v_cijene_glavni_format AS
SELECT t.naziv AS trgovac,
       c.barkod,
       c.redovna_cijena,
       c.snizena_cijena,
       COALESCE(c.snizena_cijena, c.redovna_cijena) AS efektivna_cijena   -- cijena koju kupac stvarno plati
FROM dbo.cijena c
JOIN dbo.format_prodavnice f ON f.format_id = c.format_id
JOIN dbo.trgovac t           ON t.trgovac_id = f.trgovac_id
JOIN dbo.cjenovnik cj        ON cj.cjenovnik_id = c.cjenovnik_id
WHERE cj.vrsta = 'VAZECI'
  AND t.tip = 'supermarket'
  AND f.naziv IN ('Mega Maxi', 'IDEA', 'UNIVEREXPORT - M');
GO

-- Provjera: po jedan red za svaki proizvod u svakom lancu (očekivano: 11014, 20300, 16769)
SELECT trgovac, COUNT(*) AS redova, COUNT(DISTINCT barkod) AS barkodova
FROM dbo.v_cijene_glavni_format
GROUP BY trgovac;


/* ------------------------------------------------------------
   Q5. Koliko proizvoda je u 1, 2 ili 3 lanca?   (PODUPIT u FROM)
   Unutrašnji upit broji lance po barkodu, spoljašnji broji barkodove po tom broju.
   ------------------------------------------------------------ */
SELECT broj_lanaca, COUNT(*) AS broj_proizvoda
FROM (
    SELECT barkod, COUNT(*) AS broj_lanaca
    FROM dbo.v_cijene_glavni_format
    GROUP BY barkod
) AS x
GROUP BY broj_lanaca
ORDER BY broj_lanaca;


/* ------------------------------------------------------------
   Q6. Cijene jednog proizvoda jedna pored druge   (PIVOT preko CASE WHEN)
   Jedan red po barkodu, tri kolone sa cijenama. HAVING COUNT(*) = 3 zadržava samo
   proizvode koji postoje u sva tri lanca (HAVING je WHERE za grupe).
   ------------------------------------------------------------ */
SELECT TOP 10 barkod,
       MAX(CASE WHEN trgovac = 'Delhaize'     THEN redovna_cijena END) AS delhaize,
       MAX(CASE WHEN trgovac = 'IDEA'         THEN redovna_cijena END) AS idea,
       MAX(CASE WHEN trgovac = 'Univerexport' THEN redovna_cijena END) AS univerexport
FROM dbo.v_cijene_glavni_format
GROUP BY barkod
HAVING COUNT(*) = 3;


/* ------------------------------------------------------------
   Q7. Ko je najjeftiniji?   (CTE + prozorska funkcija RANK)
   RANK() OVER (PARTITION BY barkod ORDER BY cijena): za svaki proizvod rangira lance
   od najjeftinijeg (mjesto 1). Ako dva lanca imaju istu najnižu cijenu, oba dobiju mjesto 1.
   Zato zbir udjela može biti veći od 100%.
   ------------------------------------------------------------ */
WITH poredak AS (
    SELECT barkod, trgovac, redovna_cijena,
           RANK()   OVER (PARTITION BY barkod ORDER BY redovna_cijena) AS mjesto,
           COUNT(*) OVER (PARTITION BY barkod)                        AS broj_lanaca
    FROM dbo.v_cijene_glavni_format
)
SELECT trgovac,
       SUM(CASE WHEN mjesto = 1 THEN 1 ELSE 0 END) AS najjeftiniji,
       COUNT(*)                                    AS proizvoda,
       ROUND(100.0 * SUM(CASE WHEN mjesto = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS udio_pct
FROM poredak
WHERE broj_lanaca = 3
GROUP BY trgovac
ORDER BY udio_pct DESC;


/* ------------------------------------------------------------
   Q8. Koliko je lanac u prosjeku skuplji od najjeftinijeg?   (MIN OVER)
   Za svaki proizvod nađemo najnižu cijenu među lancima, pa računamo razliku u %.
   Prosjek je osjetljiv na rijetke ekstremne vrijednosti, pa je medijana pouzdanija.
   ------------------------------------------------------------ */
WITH x AS (
    SELECT trgovac, barkod, redovna_cijena,
           MIN(redovna_cijena) OVER (PARTITION BY barkod) AS najjeftinija,
           COUNT(*)            OVER (PARTITION BY barkod) AS broj_lanaca
    FROM dbo.v_cijene_glavni_format
)
SELECT trgovac, COUNT(*) AS proizvoda,
       ROUND(AVG(100.0 * (redovna_cijena / najjeftinija - 1)), 1) AS prosj_pct_skuplje
FROM x
WHERE broj_lanaca = 3
GROUP BY trgovac
ORDER BY prosj_pct_skuplje;
