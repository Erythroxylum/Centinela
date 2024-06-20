# Generate species range maps based on convex hull of occurrence points clipped by specific elevation ranges. Loops through species names and pulls min and max data from "spp_elev_ranges.csv" with colnames = c("ddlat", "ddlon", "tax").

# The scripts to generate country raster, make df of species elevation ranges, and run EOO.computing for clipped ranges are in Centinela_getElevations_makeClippedEOO.R

# Scripts tested on R 4.3.2

###################################
##### 4) Run EOO.computing: input species_coordinates.csv and clamped raster file based on (3), species_elevation_ranges.csv
###################################

## Install ConR, necessary for Harvard FASRC
library(devtools)
devtools::install_github("gdauby/ConR")

# load libraries
library(ConR)
library(raster)
library(sf)
library(dplyr)
library(terra)
library(lwgeom)

## 

setwd("./")

#### Get file paths: WRITE YOUR FILE NAMES in this section
####

## GeoTIFF raster
raster_path <- "elevation_COECPAPE_0.5sec_maskedforestCover_30m_COECPAPE_x20_raster80.tif"
## CSV of elevation ranges
elev_csv_path <- "elev_species_final.csv"
## GBIF archive
GBIF <- "Centinela_GBIF_873sp_28-nov-23_382204records_clean_CentinelaManual.csv"
# name of output EOO table
EOO_df_name <- "EOO_results.txt"
# name of output shapefile
EOO_sf_name <- "EOO_sf.shp"

#### Read in data
####
terra_raster <- rast(raster_path)
elev_csv <- read.csv(elev_csv_path)
gbif_data <- read.csv(GBIF, header = T)

#### Format species coordinates df
####
#Remove duplicate records (same species, latitude, and longitude)
end <- gbif_data %>% 
  distinct(decimalLatitude, decimalLongitude, species, .keep_all = TRUE)
# select latitude, longitude, and species columns in that order.
end2 <- end[, c(22,23,10)] # EDIT column numbers for latitude, longitude, species (no author)
colnames(end2) <- c("ddlat", "ddlon", "tax")
#remove top data
rm(gbif_data)
rm(end)

#### RUN Loop through species names
####
species_names <- elev_csv$species

for (targetsp in species_names) {
  # Extract coordinates
  coords_var <- end2[end2$tax == targetsp, ]
    
  # Extract min and max values from CSV for the current species
  elevation <- elev_csv %>%
    dplyr::filter(species == targetsp) %>%
    dplyr::select(species, min, max)
    
  # Apply the EOO.computing function with terra
  clipped_rastert <- terra::clamp(terra_raster, lower = elevation$min, upper = elevation$max, values=FALSE)
  x <- terra::as.polygons(clipped_rastert, round=TRUE, aggregate=TRUE, values=FALSE,na.rm=TRUE)
  s <- sf::st_as_sf(x)
  EOO_result <- EOO.computing(
    XY=coords_var, 
    country_map = s, 
    exclude.area = TRUE, 
    export_shp = TRUE
    )

  write.table(EOO_result$results, paste(gsub(" ","_",targetsp),"_EOO.txt",sep=""))
  write_sf(EOO_result$spatial, paste(gsub(" ","_",targetsp),"_EOO.shp",sep=""))
    
  # Save the EOO$result to a dataframe
  if (!exists("EOO_dataframe")) {
    EOO_dataframe <- EOO_result$results
   } else {
    EOO_dataframe <- rbind(EOO_dataframe, EOO_result$results)
   }
  write.table(EOO_result$results, paste(gsub(" ","_",targetsp),"_EOO.txt",sep=""))
  
# To generate spatial data for each taxon, change export_shp to TRUE and include code below to generate new dataframe.
  # Print the resulting dataframe
  if (!exists("EOO_spatial")) {
    EOO_spatial <- EOO_result$spatial
  } else {
    EOO_spatial <- rbind(EOO_spatial, EOO_result$spatial)
  }
}

## write EOO dataframe to file
write.table(EOO_dataframe, file = paste(EOO_df_name))
## write sf multipolygons to file. 
st_write(EOO_spatial, paste(EOO_sf_name), append=TRUE)

## DONE
