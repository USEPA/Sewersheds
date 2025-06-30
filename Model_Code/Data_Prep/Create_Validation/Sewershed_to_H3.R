library(vroom)
library(tidyverse)
library(sf)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")

# Load sewersheds
swr <- st_read("/work/GRDVULN/sewershed/Data/Validation_04032025.gpkg",layer = "Sewersheds")


# For each sewershed create grid and get H3 Coordinates
h3.sewered <- data.frame()
# 223 is too small, just ignore it.
for(n in 1:nrow(swr)){
  # Project
  prj <- st_transform(swr[n,],st_crs(5070))%>%
    st_make_valid()
  
  # Make Grid
  grid <- st_make_grid(prj, cellsize = 100, what = "centers")%>%
    st_sf()
  
  # Intersect with sewershed
  grid.intrsct <- st_intersection(grid, prj)
  
  if(nrow(grid.intrsct)>0){
    # Project back to WHS 84 and retrieve coordinates
    coords <- as.data.frame(st_coordinates(st_transform(grid.intrsct,st_crs(4326))))
    
    # Retrieve H3 Indices
    h3 <- data.frame(H3_Index = geo_to_h3(c(coords$Y,coords$X),9))%>%
      distinct()%>%
      mutate(CWNS_ID = swr$CWNS_ID[n],
             Name = swr$Name[n],
             Sewered = TRUE)
    
    h3.sewered <- rbind(h3.sewered,h3)
  }
  
  
  if(n%%100 == 0){
    print(paste0(round(100*(n/nrow(swr)),1),"% Complete --- ",round(Sys.time())))
  }
  
}

vroom_write(h3.sewered, "/work/GRDVULN/sewershed/Data_Prep/Create_Validation/Data/sewersheds_h3.csv",delim=",",
            append = FALSE)

