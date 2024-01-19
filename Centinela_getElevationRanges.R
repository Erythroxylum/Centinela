# Scripts to:
# 1) Make elevation raster of country extent -- in=raster::getData out=Geotiff *.tif
# 2) Pull coordinates from GBIF archive.
# 3) Create csv of species elevation ranges, pulling elevations from gbif, aws, or Gtiff
# Manually checked. Using mostly GBIF with input from TROPICOS (Gtiff similar to aws at all z levels)


###################################
##### 1) Make elevation raster of country extent -- in=raster::getData out=Geotiff *.tif
###################################

#download raster data
# Install and load required packages
install.packages("raster")
library(raster)

# Set the bounding box for the region that includes Panama, Colombia, Peru, and Ecuador
bbox <- c(-83, -18.5, -67, 12)  # Adjust coordinates as needed (xmin, ymin, xmax, ymax)

# Specify the resolution (in degrees)
resolution <- 0.025  # this doesn't seem to do anything

# Download the elevation data using getData function
PA_elevation_data <- getData(name = "alt",  country= "Panama", res = resolution, extent = bbox)
CO_elevation_data <- getData(name = "alt",  country= "Colombia", res = resolution, extent = bbox)
EC_elevation_data <- getData(name = "alt",  country= "Ecuador", res = resolution, extent = bbox)
PE_elevation_data <- getData(name = "alt",  country= "Peru", res = resolution, extent = bbox)

# merge rasters
rast <- merge(x = PA_elevation_data, CO_elevation_data, EC_elevation_data, PE_elevation_data)

# Save the raster data to a GeoTIFF file
writeRaster(rast, "elevation_PAN_COL_PER_ECU_0.025.tif", format = "GTiff", overwrite=T)


###################################
##### 2) Pull coordinates from GBIF archive.
###################################
library(dplyr)

# Lee los datos desde el archivo Excel
ruta_archivo <- "~/Library/Mobile Documents/com~apple~CloudDocs/0Centinela/Collections/gbif/Centinela_GBIF_873sp_28-nov-23_382204records_clean_CentinelaManual.csv"
gbif_data <- read.csv(ruta_archivo, header = T)
#Eliminar registros duplicados (misma latitud y longitud)
end <- gbif_data %>% 
  distinct(decimalLatitude, decimalLongitude, species, .keep_all = TRUE)
# reorder columns to have lat, lon, species
end2 <- end[, c(22,23,10)]
colnames(end2) <- c("ddlat", "ddlon", "tax")


#EXTRAS: generate *list* for each species if no modification is needed
#coords_list_gbif <- list()
#unique_tax_values <- unique(end2$tax)

# Loop through unique "tax" values and split the data.frame
#for (tax_value in unique_tax_values) {
#current_tax_data <- end2[end2$tax == tax_value, ]
#coords_list_gbif[[as.character(tax_value)]] <- current_tax_data
#}
# Access the individual data.frames in the list
#tax_coords <- coords_list_gbif[["example_tax"]]



###################################
##### 3) Create csv of species elevation ranges, pulling elevations from gbif, aws, or Gtiff
###################################

library(dplyr)
library(raster)
library(elevatr)

# Load species coordinates from part I
end2 # from part I
#set CRS
crs = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"

###### GBIF VERSION, print range to dataframe and all elevations to list
######
elev_list_gbif <- list()
range_df_gbif <- data.frame()
# Loop through unique species in 'end'
for (i in unique(end$species)) {
  # Filter data for the current species
  species_data <- filter(end, species == i)
  # Extract elevation values
  elev1 <- species_data %>% dplyr::select(elevation)
  # Replace values equal to 0 with NA
  elev1[elev1 == 0] <- NA
  # Calculate the range of elevation values
  range1 <- range(elev1$elevation, na.rm = TRUE)
  # Create a new row for the result dataframe
  result_row <- data.frame(species = i, min_elevation = range1[1], max_elevation = range1[2], nrecords = nrow(na.omit(elev1)))
  # Append the result row to the result dataframe
  range_df_gbif <- rbind(range_df_gbif, result_row)
  # store results to list
  elev_list_gbif[[i]] <- elev1
}

# Print the resulting dataframe
head(range_df_gbif)
write.csv(range_df_gbif,file = "elev_species_raw_gbif.csv")

## TEST
speciesname <- "Drymonia turrialvae"
species_data <- filter(end, species == speciesname)
elev1 <- species_data %>% dplyr::select(elevation)
elev1
range1 <- range(elev1$elevation, na.rm = T)
####

###### AWS VERSION from coordinates
######
# Create a list to store the results
results_list_aws <- list()
range_df_aws <- data.frame()
# set crs
crs = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
# Loop through unique species in the data
for (i in unique(end$species)) {
  # Subset data for the current species
  species_data <- filter(end, species == i)
  # Extract coordinates
  coordinates_df <- species_data %>% dplyr::select(decimalLongitude, decimalLatitude)
  #convert
  coordinates_sf <- sf::st_as_sf(coordinates_df, coords = c("decimalLongitude", "decimalLatitude"), crs = crs)
  #extract point elevation data
  sf_elev_aws <- get_elev_point(coordinates_sf, prj = crs, src = "aws", z=3)
  # Create a new row for the result dataframe
  result_row <- data.frame(species = i, min_elevation = min(sf_elev_aws$elevation), max_elevation = max(sf_elev_aws$elevation), nrecords = length(na.omit(sf_elev_aws$elevation)))
  # Append the result row to the result dataframe
  range_df_aws <- rbind(range_df_aws, result_row)
  # Calculate the elevation range for the current species
  elevation_range <- range(sf_elev_aws$elevation)
  #make list of all coordinate elevations per species
  results_list_aws[[i]] <- sf_elev_aws
}

# Print the resulting dataframe
head(range_df_aws)
write.csv(range_df_aws,file = "elev_species_raw_aws.csv")

###### RASTER VERSION from coordinates
######
raster_path <- "elevation_PAN_COL_PER_ECU_0.025.tif"
geotiff_raster <- raster(raster_path)
range_df_tif <- data.frame()
elevation_ranges_tif <- list()
# set crs
crs = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
# Loop through species
for (i in unique(end$species)) {
  # Subset data for the current species
  species_data2 <- filter(end, species == i)
  # Extract coordinates
  coordinates_df2 <- species_data2 %>% dplyr::select(decimalLongitude, decimalLatitude)
  #extract point elevation data
  elevation_tif <- raster::extract(geotiff_raster, coordinates_df2)
  # Create a new row for the result dataframe
  result_row <- data.frame(species = i, min_elevation = min(elevation_tif, na.rm = T), max_elevation = max(elevation_tif, na.rm=T), nrecords = length(na.omit(elevation_tif)))
  # Append the result row to the result dataframe
  range_df_tif <- rbind(range_df_tif, result_row)
  # Calculate the elevation range for the current species
  elevation_range_tif <- range(elevation_tif, na.rm=TRUE)
  #make list of all coordinate elevations per species
  elevation_ranges_tif[[i]] <- elevation_tif
}

# Print the resulting dataframe
head(range_df_tif)
write.csv(range_df_tif,file = "elev_species_raw_tif.csv")

