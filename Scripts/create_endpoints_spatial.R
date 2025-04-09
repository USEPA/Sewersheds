library(tidyverse)
library(sf)
library(vroom)


# Load Facility Names
fac.names.1 <- vroom("Data/FACILITIES.txt")%>%
  select(FACILITY_NAME,CWNS_ID,STATE_CODE)%>%
  distinct()

fac.names.2 <- vroom("Data/FACILITIES_CONFIRMED.txt")%>%
  select(FACILITY_NAME,CWNS_ID,STATE_CODE)%>%
  distinct()

fac.names <- rbind(fac.names.1,fac.names.2)%>%
  distinct()

# Load Population Served
pop.1 <- vroom("Data/POPULATION_WASTEWATER.txt")%>%
  select(CWNS_ID,TOTAL_RES_POPULATION_2022)%>%
  distinct()

pop.2 <- vroom("Data/POPULATION_WASTEWATER_CONFIRMED.txt")%>%
  select(CWNS_ID,TOTAL_RES_POPULATION_2022)%>%
  distinct()

pop <- rbind(pop.1,pop.2)%>%
  distinct()


# Load locations
sf <- vroom("Data/endpoint_coords_moved_03132025.csv")%>%
  st_as_sf(coords = c("Lon","Lat"), crs = st_crs(4269))%>%
  left_join(fac.names)%>%
  left_join(pop)%>%
  select(STATE_CODE,CWNS_ID,FACILITY_NAME,TOTAL_RES_POPULATION_2022)

st_write(sf,"Data/endpoints_w_info.gpkg", layer = "Endpoints")

# Create geocode table

# Load address data
add <- vroom("Data/PHYSICAL_LOCATION.txt")%>%
  select(CWNS_ID,ADDRESS,ADDRESS_2,CITY,STATE_CODE,ZIP_CODE)%>%
  distinct()%>%
  filter(CWNS_ID %in% sf$CWNS_ID)

vroom_write(add,"Data/Endpoints_Address.csv", delim = ",", append = FALSE)
