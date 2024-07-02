library(vroom)
library(sf)
library(tigris)


sf <- vroom("data/ep.csv", col_types = c("CWNS_ID"="c"))%>%
  st_as_sf(coords = c("X","Y"), crs = 4326)

states <- states()%>%
  select(NAME)%>%
  st_transform(4326)


intrsct <- st_intersection(sf,states)


coords <- as.data.frame(st_coordinates(intrsct))

state.join <- intrsct%>%
  st_drop_geometry()%>%
  cbind(coords)

colnames(state.join)[5] <- "STATE_NAME"
vroom_write(state.join, "data/ep_s.csv", append = FALSE)
