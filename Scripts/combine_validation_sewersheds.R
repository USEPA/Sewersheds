library(dplyr)
library(vroom)
library(sf)
library(here)

# Load original sewersheds for validation
orig <- st_read(here("Data/Validation/Validation_Sewersheds.shp"))%>%
  select(Name)

# Load Massachusetts sewersheds
mass <- st_read(here("Data/Validation/MASS_Training.gdb"), layer = "sewersheds")%>%
  select(TRTMTPLANT)%>%
  st_transform(st_crs(orig))%>%
  setNames(c("Name","geometry"))

st_geometry(mass) <- "geometry"

# Load Join table for CWNS IDs
joins <- vroom(here("Data/Validation/Validation_Join.csv"), col_types = c("CWNS_ID"="c"))%>%
  distinct()

joined <- rbind(orig,mass)%>%
  left_join(joins, by = "Name")%>%
  select(Name, CWNS_ID, geometry)%>%
  filter(!is.na(CWNS_ID))%>%
  st_make_valid()%>%
  st_transform(4326)

st_write(joined,here("Data/Validation/Validation_Sewersheds_Combined.shp"), delete_dsn = TRUE, quiet = TRUE)

# Save end point layer
endpoints <- vroom(here("Data/endpoint_coords_moved_03132025_2.csv"))%>%
  filter(CWNS_ID %in% joined$CWNS_ID)%>%
  st_as_sf(coords = c("Lon","Lat"), crs = st_crs(4269))%>%
  st_transform(st_crs(4326))
st_write(endpoints, here("Data/Validation/Validation_Endpoints_Combined.shp"), delete_dsn = TRUE, quiet = TRUE)
