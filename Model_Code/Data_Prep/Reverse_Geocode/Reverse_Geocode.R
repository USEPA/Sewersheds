library(arcgisutils)
library(arcgisgeocode)
library(h3)
library(sf)
library(dplyr)
library(leaflet)

# Authorize
set_arc_token(auth_client())

# Load geocode server
epa_gc <- geocode_server('https://utility.arcgis.com/usrsvcs/servers/92c07361d015431f88ec828c08e5c852/rest/services/StreetmapPremium_USA/GeocodeServer')

# Test reverse geocode
root <- c(39.1021415,-84.5143394)

root.h3 <- geo_to_h3(root, res = 9)

# Neighborhood
neighbors <- k_ring(root.h3,100)

neighbor.pts <- h3_to_geo_sf(neighbors)%>%
  st_as_sfc()

rgcode <- reverse_geocode(
  locations = neighbor.pts,
  geocoder = epa_gc,
  preferred_label_values ="localCity",
  location_type = "street",
  feature_type = "PointAddress"
)

results <- rgcode%>%
  st_drop_geometry()%>%
  mutate(h3_index = neighbors)%>%
  select(h3_index,neighborhood,district,city,metro_area,subregion,region,postal)

# Map local cities
ngbr <- h3_to_geo_boundary_sf(results$h3_index)%>%
  left_join(results, by = "h3_index")

st_write(ngbr,"D:/temp/Reverse_GCode.gpkg", layer = "Cincinnati")

# Leaflet map of hexagons colored by neighborhood
leaflet(ngbr) |>
  addTiles() |>
  addPolygons(
    fillColor = ~colorFactor(topo.colors(length(unique(ngbr$city))), ngbr$city)(city),
    fillOpacity = 0.7,
    color = "white",
    weight = 1,
    popup = ~paste("Neighborhood:", neighborhood, "<br>",
                   "City:", city, "<br>",
                   "District:", district, "<br>",
                   "Metro Area:", metro_area, "<br>",
                   "Subregion:", subregion, "<br>",
                   "Region:", region, "<br>",
                   "Postal Code:", postal)
  ) |>
  addMarkers(lng = root[2], lat = root[1], popup = "Root Location")


