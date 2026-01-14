library(tidyverse)
library(osmdata)
library(sf)
library(tigris)

# Load county geometries using tigris
counties_sf <- counties(cb = TRUE, resolution = "20m", class = "sf")%>%
  st_transform(crs = 4326)

# Keys and values
kv <- data.frame(key = c("man_made","man_made","man_made","man_made"),
                 value = c("clarifier","oxidation_ditch","wastewater_plant","pumping_station"))


# Check for completed counties
files <- list.files("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Neighborhoods/",pattern = ".gpkg$",
                    full.names = TRUE)

# Loop over files and get county GEOIDs
# completed <- data.frame()
# for(n in 1:length(files)){
#   layers <- st_layers(files[n])$name
#   
#   # Create new rows
#   new.rows <- data.frame(layer = layers)%>%
#     separate(layer,into = c("STUSPS","GEOID"),sep = "_",remove = FALSE)
#   
#   completed <- rbind(completed,new.rows)
# }

# Find the geoid that appears last in counties_sf
#max(which(counties_sf$GEOID %in% completed$GEOID))

# Cincinnati test
c <- 2866

# Iterate over each county
for (c in 109:nrow(counties_sf)) {
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
    add_osm_feature(key = 'man_made', value = "wastewater_plant")%>%
    osmdata_sf()
  
  # Get polygons
  if(!is_null(osmdata$osm_polygons)){
    polys <- osmdata$osm_polygons
    
    # If name does not exist, create it
    if(!"name" %in% colnames(polys)){
      polys <- polys%>%
        mutate(name = NA)
    }
    
    st_write(polys,paste0("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants/",counties_sf$STUSPS[c],"_polys.gpkg"),
             layer = paste0(counties_sf$STUSPS[c],"_",counties_sf$GEOID[c]),append = FALSE)
  }
  
  # # Get multipolygons
  # if(!is_null(osmdata$osm_multipolygons)){
  #   mpolys <- osmdata$osm_multipolygons
  #   
  #   # If name does not exist, create it
  #   if(!"name" %in% colnames(mpolys)){
  #     mpolys <- mpolys%>%
  #       mutate(name = NA)
  #   }
  #   
  #   st_write(mpolys,paste0("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants/",counties_sf$STUSPS[c],"_mpolys.gpkg"),
  #            layer = paste0(counties_sf$STUSPS[c],"_",counties_sf$GEOID[c]),append = FALSE)
  # }
  # 
  # # Get points
  # if(!is_null(osmdata$osm_points)){
  #   points <- osmdata$osm_points
  #   
  #   # If name does not exist, create it
  #   if(!"name" %in% colnames(points)){
  #     points <- points%>%
  #       mutate(name = NA)
  #   }
  #   
  #   st_write(points,paste0("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants/",counties_sf$STUSPS[c],"_points.gpkg"),
  #            layer = paste0(counties_sf$STUSPS[c],"_",counties_sf$GEOID[c]),append = FALSE)
  # }
  
}


# Merge all county files into a single multipolygon file.

## Data frame of file paths
poly.files <- data.frame(path = list.files("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants",
                                           full.names = TRUE, pattern = "_polys.gpkg"),
                         file = list.files("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants",
                                           full.names = FALSE, pattern = "_polys.gpkg"))

## Loop over poly files and list layers
poly.layers <- data.frame()
for(n in 1:nrow(poly.files)){
  layers <- st_layers(poly.files$path[n])$name
  
  # Create new rows
  new.rows <- data.frame(file = poly.files$file[n],
                         layer = layers)%>%
    separate(layer,into = c("STUSPS","GEOID"),sep = "_",remove = FALSE)%>%
    mutate(GEOID = str_replace(GEOID,".gpkg",""))
  
  poly.layers <- rbind(poly.layers,new.rows)
}

# Repeat for multipolygons
mpoly.files <- data.frame(path = list.files("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants",
                                            full.names = TRUE, pattern = "_mpolys.gpkg"),
                          file = list.files("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants",
                                            full.names = FALSE, pattern = "_mpolys.gpkg"))
## Loop over mpoly files and list layers
mpoly.layers <- data.frame()
for(n in 1:nrow(mpoly.files)){
  layers <- st_layers(mpoly.files$path[n])$name
  
  # Create new rows
  new.rows <- data.frame(file = mpoly.files$file[n],
                         layer = layers)%>%
    separate(layer,into = c("STUSPS","GEOID"),sep = "_",remove = FALSE)%>%
    mutate(GEOID = str_replace(GEOID,".gpkg",""))
  
  mpoly.layers <- rbind(mpoly.layers,new.rows)
}

# list layers that have polygons and multipolygons
both <- as.data.frame(table(c(poly.layers$GEOID,mpoly.layers$GEOID)))%>%
  filter(Freq == 2)

# Loop over counties with both and combine
combined.polygons <- data.frame()

for(g in 1:nrow(both)){
  poly.file <- poly.layers%>%
    filter(GEOID == both$Var1[g])
  
  polygons <- st_read(paste0("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants/",
                             poly.file$file),layer = poly.file$layer)
  
  if(!"name" %in% colnames(polygons)){
    polygons <- polygons%>%
      mutate(name = NA)
  }
  
  poly.convert <- st_cast(polygons,"MULTIPOLYGON")%>%
    select(name)
  
  
  mpoly.file <- mpoly.layers%>%
    filter(GEOID == both$Var1[g])
  
  multipolygons <- st_read(paste0("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants/",
                                  mpoly.file$file),layer = mpoly.file$layer)
  
  if(!"name" %in% colnames(multipolygons)){
    multipolygons <- multipolygons%>%
      mutate(name = NA)
  }
  
  output <- multipolygons%>%
    select(name)%>%
    rbind(poly.convert)
  
  combined.polygons <- rbind(combined.polygons,output)
  
  
}


# Loop over the rest of the polygons and add them
only.polys <- poly.layers%>%
  filter(!GEOID %in% both$Var1)

pb <- txtProgressBar(min = 0, max = nrow(only.polys), style = 3)

for(i in 1:nrow(only.polys)){
  poly.file <- only.polys[i, ]
  
  polygons <- st_read(paste0("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants/",
                             poly.file$file),layer = poly.file$layer, quiet = TRUE)
  
  if(!"name" %in% colnames(polygons)){
    polygons <- polygons%>%
      mutate(name = NA)
  }
  
  poly.convert <- polygons%>%
    st_cast("MULTIPOLYGON")%>%
    select(name)
  combined.polygons <- rbind(combined.polygons,poly.convert)
  
  setTxtProgressBar(pb, i)
}


# Loop over the rest of the multipolygons and add them
only.mpolys <- mpoly.layers%>%
  filter(!GEOID %in% both$Var1)

pb <- txtProgressBar(min = 0, max = nrow(only.mpolys), style = 3)

valid <- st_make_valid(combined.polygons)

st_write(valid,"C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants.gpkg",
         layer = "Polygons", append = FALSE)

pts <- st_point_on_surface(valid)

st_write(pts,"C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Data/OSM/Wastewater_Plants.gpkg",
         layer = "Points", append = FALSE)


