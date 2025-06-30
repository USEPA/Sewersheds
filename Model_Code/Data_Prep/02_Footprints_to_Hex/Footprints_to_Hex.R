library(tidyverse)
library(sf)
library(vroom)
library(R.utils)
library(geojsonsf)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")

# Select state
st.fips <- Sys.getenv("VAR")
#st.fips <- "44"


print(paste0("Starting at: ",round(Sys.time())))

# This script downloads a temporary copy of building footprints and extracts data for H3 Hexagons


# Load join table to filter blocks based on quadkey
blk.qk <- read_csv("/work/GRDVULN/sewershed/Data/All_Block_QuadKey_Joins.csv")%>%
  filter(substr(GEOID,1,2)==st.fips)%>%
  select(quadkey)%>%
  distinct()

print(paste0("Loading Links at: ",round(Sys.time())))

# Load building footprint links for state
links <- read_tsv("/work/GRDVULN/sewershed/Data/mbfp_QuadKey_Join.csv")%>%
  filter(QuadKey %in% blk.qk$quadkey)%>%
  select(QuadKey, Url)%>%
  distinct()

print(paste0("quadkeys to download: ",nrow(links)))

# Download State Files, compute statistics, and query h3_index
print(paste0("Downloading and Joining footprints to Hex @ ", round(Sys.time())))

# Iterate through links
hex.bldgs.out <- data.frame()
for(i in 1:nrow(links)){
  
  print(paste0("Downloading Footprints for link ",i," @ ", Sys.time()))
  # Download Zip File
  dir.create(paste0("/work/GRDVULN/sewershed/temp_",st.fips), showWarnings = FALSE)
  download.file(links$Url[i],
                paste0("/work/GRDVULN/sewershed/temp_",st.fips,"/temp.csv.gz"),
                method = "curl", quiet = TRUE, mode = "w",
                cacheOK = TRUE,
                extra = getOption("download.file.extra"),
                headers = NULL)
  
  print(paste0("File Downloaded... unzipping... ",Sys.time()))
  # Unzip
  zipF <- paste0("/work/GRDVULN/sewershed/temp_",st.fips,"/temp.csv.gz")
  gunzip(zipF)
  
  print(paste0("Reading in data and making spatial... ",Sys.time()))
  
  # Read csv as character, format, and convert to sf object
  sf <- readLines(paste0("/work/GRDVULN/sewershed/temp_",st.fips,"/temp.csv"))%>% 
    paste(collapse = ", ") %>%
    {paste0('{"type": "FeatureCollection",
           "features": [', ., "]}")}%>%
    geojson_sf()%>%
    st_transform(st_crs(5070))%>%
    mutate(Area_m = as.numeric(st_area(.)))%>%
    st_point_on_surface()%>%
    st_transform(st_crs(4326))
  
  print(paste0("Retrieving coordinates... ",Sys.time()))
  sf.coords <- as.data.frame(st_coordinates(sf))
  
  bldgs.df <- cbind(st_drop_geometry(sf),sf.coords)
  
  # Retrieve h3 indices
  print(paste0("Retrieving H3 Indexes for Buildings... ",Sys.time()))
  
  bldgs.df$h3_index <- geo_to_h3(c(bldgs.df$Y,bldgs.df$X), 9)
  
  # Append to state dataset
  hex.bldgs.out <- rbind(hex.bldgs.out,bldgs.df)
  
  print(paste0("Deleting Footprints... ",Sys.time()))
  # Delete Temporary Folder
  unlink(paste0("/work/GRDVULN/sewershed/temp_",st.fips), recursive = TRUE)
  
  print(paste0(i," Files Succesfully Downloaded --- ",round(Sys.time())))
}

# Save output
write_csv(hex.bldgs.out,paste0("/work/GRDVULN/sewershed/Data_Prep/02_Footprints_to_Hex/outputs/MBFP_",st.fips,".csv"), append = FALSE)

print(paste0("SCRIPT COMPLETE @ ",round(Sys.time())))


