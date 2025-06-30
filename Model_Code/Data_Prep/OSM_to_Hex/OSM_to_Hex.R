library(dplyr)
library(sf)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
library(osmdata)
library(tidyr)
library(vroom)

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- '44'

# Alaska and California counties are too large to extract OSM, so we use subcounties for those

if(st.fips %in% c("02","06")){
  counties <- st_read("/work/GRDVULN/data/cb_2021_us_all_500k.gdb", layer = "cb_2021_us_cousub_500k")%>%
    filter(STATEFP == st.fips)%>%
    select(GEOID,STATEFP)%>%
    st_transform(st_crs(4326))%>%
    st_make_valid()
  
  print(paste0("Extracting Highways for ",nrow(counties)," Sub-Counties @ ",round(Sys.time())))
} else{
  # Load the counties
  counties <- st_read("/work/GRDVULN/sewershed/Data/US_county_2022.shp")%>%
    filter(STATEFP == st.fips)%>%
    select(GISJOIN,STATEFP)%>%
    st_transform(st_crs(4326))%>%
    st_make_valid()
  
  print(paste0("Extracting Highways for ",nrow(counties)," Counties @ ",round(Sys.time())))
}


# Iterate through counties
highways <- data.frame()

for(n in 1:nrow(counties)){
  # Download Roads from osm
  bb <- st_bbox(counties[n,])
  
  
  # Use error handler for failures (Typically very large geographic areas)
  
  tryCatch({
    # Fetch highways
    hwy <- bb%>%
      opq(timeout = 600)%>%
      add_osm_feature(key = 'highway', value = c("trunk","primary","secondary","tertiary","residential"))%>%
      osmdata_sf()
    
    # extract lines
    hwy.lines <- select(hwy$osm_lines,osm_id,highway)%>%
      group_by(highway)%>%
      summarise()%>%
      mutate(rank = recode(highway,trunk=5,primary=4,secondary=3,tertiary = 2, residential = 1))
    
    # Get H3 Hexagons
    bb.sf <- st_as_sfc(bb)%>%
      st_sf()%>%
      st_transform(st_crs(5070))%>%
      st_make_grid(250,what = "centers")%>%
      st_sf()%>%
      st_transform(4326)
    
    h3 <- unique(geo_to_h3(bb.sf,9))
    
    h3.sf <- h3_to_geo_boundary_sf(h3)
    
    # Intersect highways with hexagons
    hwy.hex <- st_join(h3.sf,hwy.lines)%>%
      st_drop_geometry()%>%
      drop_na()%>%
      group_by(h3_index)%>%
      summarise(Max_Hwy = max(rank),
                Min_Hwy = min(rank))
    
    highways <- rbind(highways,hwy.hex)
    
    print(paste0("Completed ", n, " Rows @ ",round(Sys.time())))
  }, error=function(e){print(paste0("FAILED TO DOWNLOAD ROW: ",n))})
  
  
}

# Save highway file
vroom_write(highways,paste0("/work/GRDVULN/sewershed/Data_Prep/OSM_to_Hex/outputs/","HWY_",st.fips,".csv"), delim = ",", append = FALSE)

print(paste0("Script Complete @ ",round(Sys.time())))
