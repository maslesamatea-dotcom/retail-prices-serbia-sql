/* ============================================================
   01 UVOZ PODATAKA (BULK INSERT iz CSV fajlova)
   PRIJE POKRETANJA: promijeni putanju u prvom redu ispod
   tako da pokazuje na folder `csv` koji si raspakovala.
   Putanja mora završavati kosom crtom \ .
   ============================================================ */
DECLARE @putanja NVARCHAR(260) = N'C:\retail-prices-serbia-sql\data\mssql_csv\';     -- <<< PROMIJENI OVO

DECLARE @tabele TABLE (ord INT, tabela SYSNAME);
INSERT INTO @tabele VALUES (1,'trgovac'),(2,'format_prodavnice'),(3,'kategorija'),(4,'proizvod'),
                           (5,'cjenovnik'),(6,'cijena'),(7,'kvalitet_log');

DECLARE @i INT = 1, @t SYSNAME, @sql NVARCHAR(MAX);
WHILE @i <= 7
BEGIN
    SELECT @t = tabela FROM @tabele WHERE ord = @i;
    SET @sql = N'BULK INSERT dbo.' + QUOTENAME(@t) + N' FROM ''' + @putanja + @t + N'.csv'' '
             + N'WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', CODEPAGE = ''65001'', KEEPNULLS, TABLOCK);';
    PRINT @sql;
    EXEC sys.sp_executesql @sql;
    SET @i += 1;
END;

/* Provjera: očekivani brojevi redova
   trgovac 4 | format_prodavnice 12 | kategorija 25 | proizvod 44587 | cjenovnik 12 | cijena 456538 | kvalitet_log 14 */
SELECT 'trgovac' AS tabela, COUNT(*) AS redova FROM dbo.trgovac
UNION ALL SELECT 'format_prodavnice', COUNT(*) FROM dbo.format_prodavnice
UNION ALL SELECT 'kategorija',        COUNT(*) FROM dbo.kategorija
UNION ALL SELECT 'proizvod',          COUNT(*) FROM dbo.proizvod
UNION ALL SELECT 'cjenovnik',         COUNT(*) FROM dbo.cjenovnik
UNION ALL SELECT 'cijena',            COUNT(*) FROM dbo.cijena
UNION ALL SELECT 'kvalitet_log',      COUNT(*) FROM dbo.kvalitet_log;
