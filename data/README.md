# Data

The raw data are **not included** in the repository. Download them from the open data portal (data.gov.rs). Each retailer has its own dataset titled
*Price lists of products according to the Rulebook on the conditions, content and manner of publishing price lists*. On the dataset page download the main CSV file (not XLSX):

| Retailer | Dataset page | File expected by the script in `data/raw/` |
|---|---|---|
| Delhaize Serbia (Maxi) | https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-delhaize-serbia-doo-beograd/ | `cene_proizvoda_Delhaize.csv` |
| IDEA (Mercator, Roda) | https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-idea-marketi-doo/ | `cene_proizvoda_ideamarketi.csv` |
| Univerexport | https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-univerexport-export-import-doo-1/ | `univer.csv` |
| dm drogerie markt | https://data.gov.rs/sr/datasets/cenovnici-proizvoda-prema-pravilniku-o-uslovima-sadrzaju-i-nacinu-objavljivanja-cenovnika-dm-drogerie-markt/ | `cene-proizvoda-dmdrogeriemarkt-data.csv` |

If you save the files under different names, change the `FAJLOVI` dictionary at the top of `src/01_build_sqlite_db.py`.

**Licence:** Serbian Open Data Licence. The source and the download date must be stated.

**Note:** the datasets are updated, so newer downloads will give different numbers than those in the README (the analysis was done on price lists downloaded on 23 October 2026).
