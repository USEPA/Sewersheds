library(dplyr)
library(ggplot2)
library(vroom)
library(sf)
library(h3)

df <- vroom("Model_Review_App/Data/Predictions/Prob_39.csv", col_types = c("Near_CWNS"="c"))%>%
  filter(Near_CWNS == "39003369002")


# Histogram
ggplot(df)+
  geom_histogram(aes(x = .pred_TRUE))


# Get H3 hexagons
h3 <- h3_to_geo_boundary_sf(unique(df$h3_index))%>%
  left_join(df)

st_write(h3,"D:/temp/OH_Test.gpkg", layer = "Mill_Creek")


# Hexagons to check
check <- data.frame(h3_index = k_ring("892a9308357ffff", radius = 2))%>%
  filter(!h3_index %in% df$h3_index)

check.probs <- read.csv("Model_Review_App/Data/temp_hex.csv")

check.h3 <- h3_to_geo_boundary_sf(unique(check.probs$h3_index))%>%
  left_join(check.probs)

st_write(check.h3,"D:/temp/OH_Test.gpkg", layer = "h3_Select")



## All Mill Creek Probabilities
mc <- vroom("Model_Review_App/Data/Mill_Creek_Probs.csv")%>%
  distinct()

mc.h3 <- h3_to_geo_boundary_sf(unique(mc$h3_index))%>%
  left_join(mc)


# Sewersheds H3
swr.h3 <- vroom("Model_Review_App/Data/sewersheds_h3.csv")

swr.sf <- h3_to_geo_boundary_sf(unique(swr.h3$H3_Index))%>%
  left_join(swr.h3, by = c("h3_index"="H3_Index"))

st_write(swr.sf,"D:/temp/swr_h3.gpkg", layer = "Sewersheds")

root <- h3_to_geo_boundary_sf("892b89070c3ffff")
st_write(root,"D:/temp/root.shp")




# Look at probabilities
probs <- vroom("temp/probs.csv")

h3.probs <- h3_to_geo_boundary_sf(unique(probs$h3_index))%>%
  left_join(probs)

st_write(h3.probs,"D:/temp/probs.gpkg", layer = "TestSet")


# Reproduce k-ring
ring <- k_ring_distances("892b89070c3ffff", radius = 90)
ring.sf <- h3_to_geo_boundary_sf(ring$h3_index)%>%
  left_join(ring)
st_write(ring.sf,"D:/temp/ring.shp")

check <- h3_to_geo_boundary_sf("892b89070c7ffff")
leaflet(check)%>%
  addTiles()%>%
  addPolygons()
temp <- check.h3%>%
  filter(h3_index == "892a930837bffff")

# Load training and testing
tt.sf <- st_read("Model_Review_App/Data/Tuning.gpkg", layer = "H3")

temp <- tt.sf%>%
  filter(h3_index == "892b89070c7ffff")

leaflet(temp[1,])%>%
  addTiles()%>%
  addPolygons()
# Select one endpoint
# System Data
## Population
pop <- vroom("Data/POPULATION_WASTEWATER.txt")%>%
  select(CWNS_ID,TOTAL_RES_POPULATION_2022)

#cwns <- vroom("Model_Review_App/Data/FACILITIES.txt")
cwns <- vroom("Data/FACILITIES.txt")%>%
  select(FACILITY_NAME,CWNS_ID,STATE_CODE)%>%
  left_join(pop)%>%
  filter(STATE_CODE == "NY")
