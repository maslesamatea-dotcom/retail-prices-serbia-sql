/* ============================================================
   00 ŠEMA ZA SQL SERVER (T-SQL)
   Pokreni ovo PRVO, u novoj bazi (vidi UPUTSTVO.txt).
   ============================================================ */
CREATE TABLE dbo.trgovac (
    trgovac_id  INT           NOT NULL PRIMARY KEY,
    naziv       NVARCHAR(50)  NOT NULL UNIQUE,
    tip         VARCHAR(20)   NOT NULL CHECK (tip IN ('supermarket', 'drogerija'))
);

CREATE TABLE dbo.format_prodavnice (          -- npr. Maxi, Mega Maxi, MERCATOR, RODA
    format_id   INT           NOT NULL PRIMARY KEY,
    trgovac_id  INT           NOT NULL REFERENCES dbo.trgovac(trgovac_id),
    naziv       NVARCHAR(60)  NOT NULL,
    CONSTRAINT uq_format UNIQUE (trgovac_id, naziv)
);

CREATE TABLE dbo.kategorija (                 -- zajednička šifra od 25 kategorija
    kategorija_id INT           NOT NULL PRIMARY KEY,
    naziv         NVARCHAR(120) NOT NULL
);

CREATE TABLE dbo.proizvod (                   -- jedan proizvod = jedan barkod
    barkod        VARCHAR(20)   NOT NULL PRIMARY KEY,
    naziv         NVARCHAR(300) NULL,
    robna_marka   NVARCHAR(200) NULL,
    kategorija_id INT           NULL REFERENCES dbo.kategorija(kategorija_id)
);

CREATE TABLE dbo.cjenovnik (                  -- trgovac + datum + vrsta (presjek ili važeći)
    cjenovnik_id INT         NOT NULL PRIMARY KEY,
    trgovac_id   INT         NOT NULL REFERENCES dbo.trgovac(trgovac_id),
    datum        DATE        NOT NULL,
    vrsta        VARCHAR(20) NOT NULL CHECK (vrsta IN ('MJESECNI_PRESJEK', 'VAZECI')),
    CONSTRAINT uq_cjenovnik UNIQUE (trgovac_id, datum, vrsta)
);

CREATE TABLE dbo.cijena (                     -- tabela činjenica
    cijena_id           INT           NOT NULL PRIMARY KEY,
    format_id           INT           NOT NULL REFERENCES dbo.format_prodavnice(format_id),
    cjenovnik_id        INT           NOT NULL REFERENCES dbo.cjenovnik(cjenovnik_id),
    barkod              VARCHAR(20)   NOT NULL REFERENCES dbo.proizvod(barkod),
    jedinica            VARCHAR(20)   NULL,
    jedinica_grupa      VARCHAR(20)   NULL,       -- masa / zapremina / komad / duzina
    redovna_cijena      DECIMAL(12,2) NOT NULL CHECK (redovna_cijena > 0),
    cijena_po_jedinici  DECIMAL(14,2) NULL,
    snizena_cijena      DECIMAL(12,2) NULL,       -- NULL = nema sniženja
    pocetak_snizenja    DATE          NULL,
    kraj_snizenja       DATE          NULL,
    pdv                 INT           NULL,
    CONSTRAINT uq_cijena UNIQUE (format_id, cjenovnik_id, barkod)
);

CREATE INDEX ix_cijena_barkod    ON dbo.cijena(barkod);
CREATE INDEX ix_cijena_cjenovnik ON dbo.cijena(cjenovnik_id);

CREATE TABLE dbo.kvalitet_log (               -- šta je očišćeno i zašto
    stavka   NVARCHAR(100) NULL,
    trgovac  NVARCHAR(50)  NULL,
    broj     INT           NULL,
    odluka   NVARCHAR(200) NULL
);
