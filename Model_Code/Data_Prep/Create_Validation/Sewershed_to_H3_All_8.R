library(vroom)
library(tidyverse)
library(sf)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")

# Load sewersheds
swr <- st_read("/work/GRDVULN/sewershed/Data/Final_Utility_Boundaries.gpkg",layer = "Boundaries_05052025")%>%
  st_transform(st_crs(5070))%>%
  st_make_valid()%>%
  mutate(Area = as.numeric(st_area(.)))%>%
  filter(Area > 0)%>%
  arrange(Area)

# TESTING
# swr <- swr%>%
#   filter(CWNS_ID %in% c("55003100001","55002781001"))

# For each sewershed create grid and get H3 Coordinates
h3.sewered <- data.frame()
# 223 is too small, just ignore it.
for(n in 1:nrow(swr)){
  # Project
  prj <- swr[n,]
  
  # if(prj$Area < 62500){
  #   cs <- 25
  # } else{cs <- 100}
  
  # Make Grid
  grid <- st_make_grid(prj, cellsize = 400, what = "centers")%>%
    st_sf()
  
  # Intersect with sewershed
  grid.intrsct <- st_intersection(grid, prj)
  
  if(nrow(grid.intrsct)>0){
    # Project back to WHS 84 and retrieve coordinates
    coords <- as.data.frame(st_coordinates(st_transform(grid.intrsct,st_crs(4326))))
    
    # Retrieve H3 Indices
    h3 <- data.frame(H3_Index = geo_to_h3(c(coords$Y,coords$X),8))%>%
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

vroom_write(h3.sewered, "/work/GRDVULN/sewershed/Data_Prep/Create_Validation/Data/ALL_sewersheds_h3_8.csv",delim=",",
            append = FALSE)

# plot(st_geometry(h3.sf[2,]))
# plot(st_geometry(swr.prj[2,]), add = TRUE, col = "red")
# plot(st_geometry(st_transform(grid.intrsct,st_crs(4326))), add = TRUE, col = "yellow")
# 
# # Testing (create sewersheds to map)
# h3.sf <- h3_to_geo_boundary_sf(h3.sewered$H3_Index)%>%
#   left_join(h3.sewered, by = c("h3_index"="H3_Index"))%>%
#   group_by(CWNS_ID)%>%
#   summarise()
# 
# st_write(h3.sf,"/work/GRDVULN/sewershed/temp/SWR_2_H3_V1.shp")
# 
# 
# # Try with a buffer, then an intersection
# h3.sewered.v2 <- data.frame()
# # 223 is too small, just ignore it.
# for(n in 1:nrow(swr)){
#   # Project
#   prj <- st_transform(swr[n,],st_crs(5070))
#   
#   buf <- prj%>%
#     st_buffer(2000)
#   
#   # Make Grid
#   grid <- st_make_grid(buf, cellsize = 500, what = "centers")%>%
#     st_sf()
#   
#   # Intersect with sewershed
#   grid.intrsct <- st_intersection(grid, buf)%>%
#     st_transform(st_crs(4326))
#   
#   if(nrow(grid.intrsct)>0){
#     # Project back to WHS 84 and retrieve coordinates
#     wgs <- st_transform(prj, st_crs(4326))
#     
#     coords <- as.data.frame(st_coordinates(grid.intrsct))
#     
#     # Retrieve H3 Indices
#     h3 <- unique(geo_to_h3(c(coords$Y,coords$X),8))
#     
#     # Intersect hexagons with original sewershed
#     h3.sf <- h3_to_geo_boundary_sf(h3)
#     
#     h3.intrsct <- st_intersection(h3.sf,wgs)
#     
#     h3.out <- data.frame(h3_index = unique(h3.intrsct$h3_index),
#                          CWNS_ID = swr$CWNS_ID[n],
#                          Name = swr$FACILITY_NAME[n])
#     
#     h3.sewered.v2 <- rbind(h3.sewered.v2,h3.out)
#   }
#   
#   
#   if(n%%100 == 0){
#     print(paste0(round(100*(n/nrow(swr)),1),"% Complete --- ",round(Sys.time())))
#   }
#   
# }
# 
# # Testing (create sewersheds to map)
# h3.sf.2 <- h3_to_geo_boundary_sf(h3.sewered.v2$h3_index)%>%
#   left_join(h3.sewered.v2)%>%
#   group_by(CWNS_ID)%>%
#   summarise()
# 
# st_write(h3.sf.2,"/work/GRDVULN/sewershed/temp/SWR_2_H3_V2.shp")
# 
# 
# 
# 
# 
# # Try Using the data that we are going to actually use
# 
# validation <- vroom("/work/GRDVULN/sewershed/Data_Prep/Prepare_Inputs/outputs_8/FP_55.csv")%>%
#   filter(Near_CWNS %in% swr$CWNS_ID)
# 
# # Get h3 hexagons spatial
# valid.h3 <- h3_to_geo_boundary_sf(unique(validation$h3_index))
# 
# # Intersect with sewersheds
# valid.intrsct <- st_intersection(valid.h3,st_transform(swr,st_crs(4326)))
# 
# intrsct.sel <- valid.intrsct%>%
#   st_drop_geometry()%>%
#   select(h3_index,CWNS_ID,FACILITY_NAME)%>%
#   distinct()
# 
# # Build sewersheds
# v3 <- h3_to_geo_boundary_sf(intrsct.sel$h3_index)%>%
#   left_join(intrsct.sel)%>%
#   group_by(CWNS_ID)%>%
#   summarise()
# 
# st_write(v3,"/work/GRDVULN/sewershed/temp/SWR_2_H3_V3.shp")




