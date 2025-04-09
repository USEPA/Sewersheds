library(vroom)
library(dplyr)
library(here)
library(sf)

coords <- vroom("D:/Github/Sewersheds/Data/endpoint_coords_moved_03132025.csv")


# 36007222001 is 76.3074565°W 42.4928748°N 
i1 <- which(coords$CWNS_ID == "36007222001")

coords$Lon[i1] <- -76.3074565
coords$Lat[i1] <- 42.4928748

# 36008276001 is 76.7485033°W 43.2817976°N 
i2 <- which(coords$CWNS_ID == "36008276001")
coords$Lon[i2] <- -76.7485033
coords$Lat[i2] <- 43.2817976

# New row for 37009902001 at 80.8582406°W 36.2358313°N 
coords <-add_row(coords,
         CWNS_ID = "37009902001",
         Lat = 36.2358313,
         Lon = -80.8582406)


# New Row for 50000081001 at 44.15395 -72.04165
coords <-add_row(coords,
                 CWNS_ID = "50000081001",
                 Lat = 44.15395,
                 Lon = -72.04165)

vroom_write(coords,"D:/Github/Sewersheds/Data/endpoint_coords_moved_03132025_2.csv")



df <- vroom(here("Data/Facilities.txt"))

check <- "50000081001"

facility <- df%>%
  filter(CWNS_ID == check)

locs <- vroom(here("Data/PHYSICAL_LOCATION.txt"))%>%
  filter(CWNS_ID == check)
pop <- vroom(here("Data/POPULATION_WASTEWATER.txt"))%>%
  filter(CWNS_ID == check)
