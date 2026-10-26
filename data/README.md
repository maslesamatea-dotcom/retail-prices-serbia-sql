# Podaci

Sirovi podaci **nisu uključeni** u repozitorij. Preuzmi ih sa Portala otvorenih podataka (data.gov.rs). Svaki trgovac ima zaseban skup pod nazivom
*Cjenovnici proizvoda prema Pravilniku o uslovima, sadržaju i načinu objavljivanja cjenovnika*. Na stranici skupa preuzmi glavnu CSV datoteku (ne XLSX):

| Trgovac | Stranica skupa | Fajl koji skripta očekuje u `data/raw/` |
|---|---|---|
| Delhaize Serbia (Maxi) | https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-delhaize-serbia-doo-beograd/ | `cene_proizvoda_Delhaize.csv` |
| IDEA (Mercator, Roda) | https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-idea-marketi-doo/ | `cene_proizvoda_ideamarketi.csv` |
| Univerexport | https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-univerexport-export-import-doo-1/ | `univer.csv` |
| dm drogerie markt | https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-dm-drogerie-markt/ | `cene-proizvoda-dmdrogeriemarkt-data.csv` |

Ako sačuvaš fajlove pod drugim nazivima, promijeni rječnik `FAJLOVI` na početku skripte `src/01_build_sqlite_db.py`.

**Licenca:** Srpska licenca za otvorene podatke. Obavezno je navesti izvor i datum preuzimanja podataka.

**Važno:** skupovi se ažuriraju, pa će novija preuzimanja dati drugačije brojke od onih u README-u (analiza je rađena na cjenovnicima preuzetim 23.10.2026.).
