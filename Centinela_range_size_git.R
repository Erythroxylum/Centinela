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

#### Get file paths: EDIT FILE NAMES
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
#Remove duplicate records (identical species, latitude, and longitude)
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
  tryCatch({
    # Debug print for current species
    cat("Processing species:", targetsp, "\n")
    
    # Extract coordinates
    coords_var <- end2[end2$tax == targetsp, ]
    if (nrow(coords_var) == 0) {
      cat("     No coordinates found for species:", targetsp, "\n")
      next
    }
    
    # n coordinates print for current species
    cat("     Number of total coordinates for species", targetsp, ":", nrow(coords_var), "\n")
    
    # Skip species if number of coordinates is less than 3
    if (nrow(coords_var) < 3) {
      cat("     Not enough coordinates for species:", targetsp, "\n")
      next
    }
    
    # Extract min and max values from CSV for the current species
    elevation <- elev_csv %>%
      dplyr::filter(species == targetsp) %>%
      dplyr::select(species, min, max)
    
    # elevation print for current species
    cat("     Elevation for species", targetsp, ":", elevation$min, elevation$max, "\n")
    
    if (nrow(elevation) != 1) {
      cat("     Unexpected number of rows in elevation data for species:", targetsp, "\n")
      next
    }
    
    # Apply the EOO.computing function with terra
    clipped_rastert <- terra::clamp(terra_raster, lower = elevation$min, upper = elevation$max, values = FALSE)
    #x <- terra::as.polygons(clipped_rastert, round = TRUE, aggregate = TRUE, values = FALSE, na.rm = TRUE)
    x <- terra::as.polygons(clipped_rastert, values = FALSE, na.rm = TRUE)
    
    # Convert SpatVector to sf object
    x_sf <- sf::st_as_sf(x)
    
    # Clean the geometry to avoid issues
    #x_sf <- sf::st_make_valid(x_sf)
    #x_sf <- x_sf[!sf::st_is_empty(x_sf),]
    
    sf::sf_use_s2(TRUE)
    
    # Check if the resulting polygons are valid
    if (any(sf::st_is_empty(x_sf))) {
      cat("     Skipping species due to invalid geometry:", targetsp, "\n")
      next
    }
    
    # OPTIONAL: Remove coordinates that fall outside the x shapefile
    coords_sf <- st_as_sf(coords_var, coords = c("ddlon", "ddlat"), crs = st_crs(x_sf))
    valid_indices <- st_within(coords_sf, x_sf, sparse = FALSE)
    valid_indices3 <- st_within(coords_sf, x_sf, sparse = TRUE)
    valid_indices2 <- st_within(x_sf, coords_sf, sparse = FALSE)
    coords_var_valid <- coords_var_valid[complete.cases(coords_var_valid), ]
    
    # Print the number of valid coordinates
    cat("     Number of coordinates within forested areas for species", targetsp, ":", nrow(coords_var_valid), "\n")
    
    # Skip species if number of valid coordinates is less than 3
    if (nrow(coords_var_valid) < 3) {
      cat("     Not enough valid coordinates for species:", targetsp, "\n")
      next
    }
    
    # Convert filtered coordinates back to data frame with required columns
    coords_var_df <- data.frame(
      ddlat = coords_var_valid$ddlat,
      ddlon = coords_var_valid$ddlon,
      tax = coords_var_valid$tax
    )
    
    # Apply the EOO.computing function
    EOO_result <- EOO.computing(
      XY = coords_var_df, 
      country_map = x_sf, 
      exclude.area = TRUE, 
      export_shp = TRUE
    )
    
    write.table(EOO_result$results, paste(gsub(" ", "_", targetsp), "_EOO.txt", sep = ""))
    write_sf(EOO_result$spatial, paste(gsub(" ", "_", targetsp), "_EOO.shp", sep = ""))
  }, error = function(e) {
    # Print a message and skip to the next species
    cat("     An error occurred with species:", targetsp, "\nError message:", e$message, "\n")
  })
}

## DONE
