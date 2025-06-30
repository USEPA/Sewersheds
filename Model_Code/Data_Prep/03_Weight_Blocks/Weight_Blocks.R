library(tidyverse)
library(here)
library(sf)
library(vroom)
library(R.utils)
library(geojsonsf)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")

# This script downloads a temporary copy of building footprints and extracts data to H3 Hexagons

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- '44'

print(paste0("Starting ",st.fips))
# Load fips join table
fips.join <- read_csv("/work/GRDVULN/sewershed/Data/fips_join.csv")%>%
  filter(state_code == st.fips)

print(paste0("Loading quadkey joins @ ",round(Sys.time())))

# Load join table to filter blocks based on quadkey
blk.qk <- read_csv("/work/GRDVULN/sewershed/Data/All_Block_QuadKey_Joins.csv")%>%
  filter(substr(GEOID,1,2)==st.fips)

print(paste0("Loading download links @ ",round(Sys.time())))

# Load building footprint links for state
links <- read_tsv("/work/GRDVULN/sewershed/Data/mbfp_QuadKey_Join.csv")%>%
  filter(QuadKey %in% blk.qk$quadkey)%>%
  select(QuadKey, Url)%>%
  distinct()

# Load block populations and housing units and filter
blk.tbl <- read_csv("/work/GRDVULN/sewershed/Data/Census_2020.csv")%>%
  select(!GEOID)

# Load census blocks
blks <- st_read(paste0("/work/GRDVULN/census/",fips.join$state,"_block_2020.shp"))%>%
  select(GISJOIN,GEOID20)%>%
  left_join(blk.tbl)%>%
  filter(Population > 0 | THU >0)

# Download State Files and join to blocks
print(paste0("Downloading Buildings from ",nrow(links)," Quadkeys --- ", round(Sys.time())))
print(paste0("(",nrow(links),")", " Files to be Downloaded"))
weights <- data.frame()
for(n in 1:nrow(links)){
  # Download Zip File
  dir.create(paste0("/work/GRDVULN/sewershed/temp_",st.fips), showWarnings = FALSE)
  download.file(links$Url[n],
                paste0("/work/GRDVULN/sewershed/temp_",st.fips,"/temp.csv.gz"),
                method = "curl", quiet = TRUE, mode = "w",
                cacheOK = TRUE,
                extra = getOption("download.file.extra"),
                headers = NULL)
  
  # Unzip
  zipF <- paste0("/work/GRDVULN/sewershed/temp_",st.fips,"/temp.csv.gz")
  gunzip(zipF)
  
  print(paste0("Loading Buildings @ ", round(Sys.time())))
  
  # Read csv as character, format, and convert to sf object
  sf <- readLines(paste0("/work/GRDVULN/sewershed/temp_",st.fips,"/temp.csv"))%>% 
    paste(collapse = ", ") %>%
    {paste0('{"type": "FeatureCollection",
           "features": [', ., "]}")}%>%
    geojson_sf()%>%
    mutate(BID = paste0("B",links$QuadKey[n],"-",row_number()))%>%
    st_transform(st_crs(5070))%>%
    mutate(Area_m = as.numeric(st_area(.)))%>%
    filter(Area_m > 40)%>%
    st_point_on_surface()%>%
    st_transform(st_crs("ESRI:102003"))%>%
    select(BID)
  
  # Load Census blocks and filter to quadkey
  blk.filt <- blk.qk%>%
    filter(quadkey == links$QuadKey[n])
  
  blocks.qk.sf <- blks%>%
    filter(GISJOIN %in% blk.filt$GISJOIN)
  
  print(paste0("Intersecting Buildings & Blocks @ ", round(Sys.time())))
  
  # Perform spatial intersection
  bldg.intersect <- st_intersection(sf,blocks.qk.sf)%>%
    st_transform(st_crs(4326))
  
  # Get H3 indexes
  bldg.intersect$h3_index <- geo_to_h3(bldg.intersect,9)

  # Clean and save
  out.df <- bldg.intersect%>%
    st_drop_geometry()%>%
    select(BID,GISJOIN,h3_index,Population,THU,Urban_Pop)
  
  weights <- rbind(weights,out.df)
  
  
  # Delete Temporary Folder
  unlink(paste0("/work/GRDVULN/sewershed/temp_",st.fips), recursive = TRUE)
  
  print(paste0("Completed Quadkey #",n," @ ", round(Sys.time())))
}

print(paste0("Calculating Weights @ ", round(Sys.time())))

weighted <- weights%>%
  group_by(GISJOIN)%>%
  mutate(Block_Buildings = n())%>%
  ungroup()%>%
  group_by(GISJOIN,h3_index)%>%
  mutate(O_Buildings = n())%>%
  ungroup()%>%
  select(!BID)%>%
  distinct()%>%
  mutate(weight = O_Buildings/Block_Buildings)
  
# Save weighted hex file
write_csv(weighted,paste0("/work/GRDVULN/sewershed/Data_Prep/03_Weight_Blocks/outputs/Blk_Weights_",st.fips,".csv"), append = FALSE)


print(paste0("SCRIPT COMPLETE @ ",round(Sys.time())))
