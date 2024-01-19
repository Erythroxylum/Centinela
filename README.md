# Centinela
R scripts for spatial analyses of the Centinela flora. 

## GBIF download and cleaning
The GBIF data used in the paper can be accessed at:
https://drive.google.com/file/d/1DDdLYZOjQW4oCinXqJgYdWJM_PycdQ8w/view?usp=sharing

Or downloaded via rGBIF
``
d <- occ_download_get('0011588-231120084113126') %>%
    occ_download_import()
``

GBIF_download_species_notes.txt: Description of nomenclatural differences between 2024 Centinela flora list of 914 species and 873 species with GBIF data.

Centinela_rgbif_git.R: R scripts for downloading and cleaning GBIF data.

## Species ranges
elev_species_final.csv: elevational ranges per species 

elevation_PAN_COL_PER_ECU_0.5sec.tif: elevation raster

Centinela_range_size_git.R: R scripts used to estimate species range sizes in the paper. 

Users will need to download their own GBIF data, edit R script to reflect the user environment and filenames, and then run R script on the command line. The large sizes of the rasters and shapes in our analyses made this scripts run very slowly, about 30 minutes per species. I recommend splitting the elev_species_final.csv into several files that can be run in parallel on a server
