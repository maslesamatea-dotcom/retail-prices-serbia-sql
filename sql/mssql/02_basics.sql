/* ============================================================
   02 OSNOVE (upiti Q1-Q4) (SELECT, COUNT, WHERE, ORDER BY, GROUP BY, JOIN) za SQL Server
   Razlika u odnosu na SQLite: umjesto LIMIT piše se TOP (odmah poslije SELECT).
   ============================================================ */

-- Q1. Koliko ima redova u tabeli cijena i koliko različitih proizvoda (barkodova)?
SELECT COUNT(*)               AS redova,
       COUNT(DISTINCT barkod) AS razlicitih_proizvoda
FROM dbo.cijena;

-- Q2. Pet najskupljih artikala u VAŽEĆIM cjenovnicima.
SELECT TOP 5 p.naziv, t.naziv AS trgovac, c.redovna_cijena
FROM dbo.cijena c
JOIN dbo.proizvod p   ON p.barkod = c.barkod
JOIN dbo.cjenovnik cj ON cj.cjenovnik_id = c.cjenovnik_id
JOIN dbo.trgovac t    ON t.trgovac_id = cj.trgovac_id
WHERE cj.vrsta = 'VAZECI'
ORDER BY c.redovna_cijena DESC;

-- Q3. Koliko različitih proizvoda ima u svakoj kategoriji (GROUP BY)?
SELECT TOP 8 k.naziv AS kategorija, COUNT(*) AS broj_proizvoda
FROM dbo.proizvod p
JOIN dbo.kategorija k ON k.kategorija_id = p.kategorija_id
GROUP BY k.naziv
ORDER BY broj_proizvoda DESC;

-- Q4. Udio artikala na sniženju kod svakog trgovca u važećem cjenovniku.
SELECT t.naziv AS trgovac,
       COUNT(*) AS artikala,
       SUM(CASE WHEN c.snizena_cijena IS NOT NULL THEN 1 ELSE 0 END) AS na_snizenju,
       ROUND(100.0 * SUM(CASE WHEN c.snizena_cijena IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS udio_pct
FROM dbo.cijena c
JOIN dbo.cjenovnik cj ON cj.cjenovnik_id = c.cjenovnik_id
JOIN dbo.trgovac t    ON t.trgovac_id = cj.trgovac_id
WHERE cj.vrsta = 'VAZECI'
GROUP BY t.naziv
ORDER BY udio_pct DESC;
