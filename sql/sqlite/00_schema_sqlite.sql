-- Šema baze: zvjezdasta struktura (dimenzije + tabela činjenica `cijena`).
PRAGMA foreign_keys = ON;

CREATE TABLE trgovac (
    trgovac_id  INTEGER PRIMARY KEY,
    naziv       TEXT NOT NULL UNIQUE,
    tip         TEXT NOT NULL CHECK (tip IN ('supermarket', 'drogerija'))
);

CREATE TABLE format_prodavnice (          -- npr. Maxi, Mega Maxi, MERCATOR, RODA
    format_id   INTEGER PRIMARY KEY,
    trgovac_id  INTEGER NOT NULL REFERENCES trgovac(trgovac_id),
    naziv       TEXT NOT NULL,
    UNIQUE (trgovac_id, naziv)
);

CREATE TABLE kategorija (                 -- zajednička šifra od 25 kategorija
    kategorija_id INTEGER PRIMARY KEY,
    naziv         TEXT NOT NULL
);

CREATE TABLE proizvod (                   -- jedan proizvod = jedan barkod (zajednički ključ među lancima)
    barkod        TEXT PRIMARY KEY,
    naziv         TEXT,
    robna_marka   TEXT,
    kategorija_id INTEGER REFERENCES kategorija(kategorija_id)
);

CREATE TABLE cjenovnik (                  -- jedan cjenovnik = trgovac + datum + vrsta (presjek ili važeći)
    cjenovnik_id INTEGER PRIMARY KEY,
    trgovac_id   INTEGER NOT NULL REFERENCES trgovac(trgovac_id),
    datum        TEXT NOT NULL,           -- ISO: YYYY-MM-DD
    vrsta        TEXT NOT NULL CHECK (vrsta IN ('MJESECNI_PRESJEK', 'VAZECI')),
    UNIQUE (trgovac_id, datum, vrsta)
);

CREATE TABLE cijena (                     -- tabela činjenica
    cijena_id           INTEGER PRIMARY KEY,
    format_id           INTEGER NOT NULL REFERENCES format_prodavnice(format_id),
    cjenovnik_id        INTEGER NOT NULL REFERENCES cjenovnik(cjenovnik_id),
    barkod              TEXT    NOT NULL REFERENCES proizvod(barkod),
    jedinica            TEXT,             -- izvorna jedinica mjere (malim slovima)
    jedinica_grupa      TEXT,             -- masa / zapremina / komad / duzina
    redovna_cijena      REAL    NOT NULL CHECK (redovna_cijena > 0),
    cijena_po_jedinici  REAL,
    snizena_cijena      REAL,             -- NULL = nema sniženja
    pocetak_snizenja    TEXT,
    kraj_snizenja       TEXT,
    pdv                 INTEGER,
    UNIQUE (format_id, cjenovnik_id, barkod)
);

CREATE INDEX ix_cijena_barkod    ON cijena(barkod);
CREATE INDEX ix_cijena_cjenovnik ON cijena(cjenovnik_id);

CREATE TABLE kvalitet_log (               -- šta je očišćeno i zašto
    stavka   TEXT,
    trgovac  TEXT,
    broj     INTEGER,
    odluka   TEXT
);
