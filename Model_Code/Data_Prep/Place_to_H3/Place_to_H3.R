# Load census places and identify h3 hexagons within them
library(dplyr)
library(stringr)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
library(vroom)
library(sf)

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- '44'


print(paste0("Loading places @ ",round(Sys.time())))

# Load Places
places.sf <- st_read("/work/GRDVULN/data/cb_2021_us_all_500k.gdb", layer = "cb_2021_us_place_500k")%>%
  filter(STATEFP == st.fips)%>%
  select(NAME)%>%
  st_transform(st_crs(4326))%>%
  st_make_valid()
colnames(places.sf)[1] <- "Place"


# Iterate over places and get L9 Hexagons

print(paste0("Finding Hexagons for ",nrow(places.sf)," places @ ",round(Sys.time())))

hex.place <- data.frame()

for(n in 1:nrow(places.sf)){
  # Select a place
  place <- places.sf[n,]
  
  # Make a regular grid of points over the place
  pts <- place%>%
    st_transform(st_crs(5070))%>%
    st_make_grid(cellsize = 250, what = "centers")%>%
    st_sf()%>%
    st_transform(st_crs(4326))
  
  # Get H3 indexes
  pts.h3 <- geo_to_h3(pts, res = 9)
  
  # Get H3 centroids
  h3.centers <- h3_to_geo_sf(unique(pts.h3))%>%
    filter(st_intersects(.,place, sparse = FALSE))
  
  if(nrow(h3.centers)>0){
    # Create new rows
    newRows <- data.frame(h3_index = h3.centers$h3_index,
                          Place = place$Place)
    
    hex.place <- rbind(hex.place,newRows)
  }
  
  

  if(n %% 100 == 0){
    print(paste0(round(100*(n/nrow(places.sf)),1),"% Complete @ ", round(Sys.time())))
  }
}

vroom_write(hex.place, paste0("/work/GRDVULN/sewershed/Data_Prep/Place_to_H3/outputs/FP_",st.fips,".csv"))
