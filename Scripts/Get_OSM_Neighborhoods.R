library(tidyverse)
library(osmdata)
library(sf)
library(tigris)

# Load county geometries using tigris
counties_sf <- counties(cb = TRUE, resolution = "20m", class = "sf")%>%
  st_transform(crs = 4326)


# Check for completed counties
files <- list.files("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Neighborhoods/",pattern = ".gpkg$",
                    full.names = TRUE)

# Loop over files and get county GEOIDs
completed <- data.frame()
for(n in 1:length(files)){
  layers <- st_layers(files[n])$name
  
  # Create new rows
  new.rows <- data.frame(layer = layers)%>%
    separate(layer,into = c("STUSPS","GEOID"),sep = "_",remove = FALSE)
  
  completed <- rbind(completed,new.rows)
}

# Find the geoid that appears last in counties_sf
max(which(counties_sf$GEOID %in% completed$GEOID))

# Cincinnati test
#c <- 2866

# Iterate over each county
for (c in 3073:nrow(counties_sf)) {
  print(paste0("County #",c))
  county <- counties_sf[c, ]
  
  print(paste0("Starting ",county$NAMELSAD," (",county$STUSPS,") at ",round(Sys.time())))
  
  # Get bounding box coordinates
  cnty.bbox <- st_bbox(county)
  ymin <- as.numeric(cnty.bbox[2])
  xmin <- as.numeric(cnty.bbox[1])
  ymax <- as.numeric(cnty.bbox[4])
  xmax <- as.numeric(cnty.bbox[3])
  
  # Build overpass query
  osmdata <- opq(
    bbox = c(xmin,ymin,xmax,ymax),
    timeout = 300
  )%>%
    add_osm_feature(key = 'admin_level', value = 10)%>%
    osmdata_sf()
  
  # Get geometries
  if(!is_null(osmdata$polys)){
    polys <- polys <- osmdata$osm_polygons
    
    if(all(c("osm_id","name") %in% polys)){
      polys <- polys%>%
        select(osm_id,name,boundary)%>%
        st_cast("MULTIPOLYGON")
    } else(polys <- NULL)
  } else(polys <- NULL)
  
  if(!is_null(osmdata$osm_multipolygons)){
    mpolys <- osmdata$osm_multipolygons
    
    if(all(c("osm_id","name") %in% mpolys)){
      mpolys <- mpolys%>%
        select(osm_id, name, boundary)
    } else(mpolys <- NULL)
  } else(mpolys <- NULL)
  
  if(!is_null(polys) & !is_null(mpolys)){
    # Combine polygons
    output <- rbind(mpolys,polys)%>%
      drop_na(name)%>%
      group_by(name)%>%
      summarise(osm_id = osm_id[1],
                name = name[1],alt_name = alt_name[1])
  } else if(!is_null(polys) & is_null(mpolys)){
    output <- polys
  } else if(is_null(polys) & !is_null(mpolys)){
    output <- mpolys
  } else(output <- NULL)
  
  if(!is_null(output)){
    # Save output
    st_write(output,paste0("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Neighborhoods/",counties_sf$STUSPS[c],".gpkg"),
             layer = paste0(counties_sf$STUSPS[c],"_",counties_sf$GEOID[c]))
    
    print(paste0("Saving ",nrow(output)," neighborhoods for ",county$NAMELSAD," (",county$STUSPS,") at ",round(Sys.time())))
  } else(print(paste0("Nothing Found in ",county$NAMELSAD," (",county$STUSPS,")")))
}
