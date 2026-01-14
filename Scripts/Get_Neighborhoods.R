library(tigris)
library(httr)
library(jsonlite)
library(sf)
library(tidyverse)

# Load county geometries using tigris
counties_sf <- counties(cb = TRUE, resolution = "20m", class = "sf")%>%
  st_transform(crs = 4326)

# Create a function to query Overpass API for level 10 boundaries
query_overpass <- function(min_lat, min_lon, max_lat, max_lon) {
  bbox <- paste(min_lat, min_lon, max_lat, max_lon, sep = ",")
  
  query <- paste0(
    '[out:json][timeout:300];',
    'way["admin_level"="10"](bbox:', bbox, ');',
    'relation["admin_level"="10"](bbox:', bbox, ');',
    'out geom;'
  )
  
  response <- httr::POST(
    url = "http://overpass-api.de/api/interpreter",
    body = list(data = query),
    encode = "form"
  )
  
  if (response$status_code == 200) {
    data <- jsonlite::fromJSON(content(response, "text", encoding = "UTF-8"))
    return(data$elements)
  } else {
    cat("Error: Unable to retrieve data. Status code:", response$status_code, "\n")
    return(NULL)
  }
}


# Function to convert nested geometry data frames to lines and ensure closure
convert_to_closed_linestring <- function(geometry_df) {
  coords <- as.matrix(geometry_df[, c("lon", "lat")])
  
  # Ensure the linestring is closed by appending the first coordinate to the end if necessary
  # if (!all(coords[1, ] == coords[nrow(coords), ])) {
  #   coords <- rbind(coords, coords[1, ])
  # }
  
  st_linestring(coords)
}

# Cincinnati test
i <- 3175
# Iterate over each county
for (i in seq_len(nrow(counties_sf))) {
  county <- counties_sf[i, ]
  
  # Get bounding box coordinates
  cnty.bbox <- st_bbox(county)
  min_lat <- cnty.bbox[2]
  min_lon <- cnty.bbox[1]
  max_lat <- cnty.bbox[4]
  max_lon <- cnty.bbox[3]
  
  # Query Overpass API
  elements <- query_overpass(min_lat, min_lon, max_lat, max_lon)
  
  
  filter <- elements%>%
    filter(bounds$minlat >= min_lat &
             bounds$minlon >= min_lon &
             bounds$maxlat <= max_lat &
             bounds$maxlon <= max_lon)
  
  county.neighborhoods <- data.frame()
  for(neighborhood in 1:nrow(filter)){
    element <- filter[neighborhood, ]
    outer.members <- element$members[[1]]%>%
      filter(type == "way" & role == "outer")
    
    outer.lines <- lapply(seq_len(nrow(outer.members)), function(i) {
      return(convert_to_closed_linestring(outer.members$geometry[[i]]))
    })
    
    
    
    # Filter out NULLs and create sf object
    outer_lines <- outer.lines[!sapply(outer.lines, is.null)]
    outer_lines_sf <- st_sfc(outer_lines, crs = 4326)%>%
      st_sf()%>%
      mutate(id = seq_len(n()))
    
    ggplot(outer_lines_sf)+
      geom_sf(aes(color = id), linewidth = 2)+
      scale_color_viridis_c()
    
    # Determine which lines are closed
    outer_lines_sf$Closed <- NA
    for(l in 1:nrow(outer_lines_sf)){
      line <- outer_lines_sf[l,]
      coords <- as.data.frame(st_coordinates(line))
      
      coords_first <- coords[1, c("X","Y")]
      coords_last <- coords[nrow(coords), c("X","Y")]
      if(all(coords_first == coords_last)){
        outer_lines_sf$Closed[l] <- TRUE
      } else {
        outer_lines_sf$Closed[l] <- FALSE
      }
    }
    # Visualize closed vs open lines
    ggplot(outer_lines_sf)+
      geom_sf(aes(color = Closed), linewidth = 2)+
      scale_color_manual(values = c("TRUE" = "green", "FALSE" = "red"))
    
    
    # For each line, count how many other lines it touches
    outer_lines_sf$Touches <- 0
    for(l in 1:nrow(outer_lines_sf)){
      line <- outer_lines_sf[l,]
      touches_count <- 0
      for(ol in 1:nrow(outer_lines_sf)){
        if(l != ol){
          other_line <- outer_lines_sf[ol,]
          if(st_touches(line, other_line, sparse = FALSE)){
            touches_count <- touches_count + 1
          }
        }
      }
      outer_lines_sf$Touches[l] <- touches_count
    }
    
    # Visualize lines by number of touches
    ggplot(outer_lines_sf)+
      geom_sf(aes(color = as.character(Touches)), linewidth = 2)+
      scale_color_manual(values = c("0" = "orange", "1" = "red", "2" = "forestgreen"))
    
    # If there are any lines with only one touch, connect them to the closest line endpoint
    open_lines <- outer_lines_sf%>%
      filter(Touches == 1)%>%
      st_transform(st_crs(5070))
    if(nrow(open_lines) > 0){
      for(ol in 1:nrow(open_lines)){
        line <- open_lines[ol,]
        line_coords <- as.data.frame(st_coordinates(line))
        line_endpoints <- rbind(line_coords[1, c("X","Y")],
                                line_coords[nrow(line_coords), c("X","Y")])
        
        other_lines <- outer_lines_sf%>%
          filter(id != line$id)%>%
          st_transform(st_crs(5070))
        
        other_endpoints <- do.call(rbind, lapply(seq_len(nrow(other_lines)), function(i) {
          ol_line <- other_lines[i,]
          ol_coords <- as.data.frame(st_coordinates(ol_line))
          rbind(ol_coords[1, c("X","Y")],
                ol_coords[nrow(ol_coords), c("X","Y")])
        }))
        
        # Find closest endpoint
        dists <- as.matrix(dist(rbind(line_endpoints, other_endpoints)))
        dists_subset <- dists[1:2, 3:ncol(dists)]
        min_dist <- which(dists_subset == min(dists_subset), arr.ind = TRUE)
        
        line_endpoint_idx <- min_dist[1]
        other_endpoint_idx <- min_dist[2]
        
        # Create a connecting line
        connecting_line <- st_linestring(rbind(as.numeric(line_endpoints[line_endpoint_idx, ]),
                                               as.numeric(other_endpoints[other_endpoint_idx, ])))
        
        # Add connecting line to outer_lines_sf
        outer_lines_sf <- rbind(outer_lines_sf,
                                st_sf(geometry = st_sfc(connecting_line, crs = st_crs(5070)),
                                      id = max(outer_lines_sf$id) + 1,
                                      Closed = TRUE,
                                      Touches = NA)%>%
                                  st_transform(st_crs(4326)))
      }
    }
    
    # Visualize final lines
    ggplot(outer_lines_sf)+
      geom_sf(aes(color = id), linewidth = 2)+
      scale_color_viridis_c()
    
    # Now that lines are connecting, we want to order them and combine them.
    # start with the first line and the first connection, then st_combine until all lines have been merged
    
    lines.combine <- data.frame()
    connected <- FALSE
    combined.line <- outer_lines_sf[1,]
    ids <- combined.line$id
    merged <- 0
    while(connected == FALSE){
      
      remaining.lines <- outer_lines_sf%>%
        filter(!id %in% ids)
      
      if(nrow(remaining.lines) > 0){
        next.line.id <- which(st_touches(combined.line, remaining.lines, sparse = FALSE))
        
        if(is_empty((next.line.id))){
          print("No more connected lines found.")
          break
        } else{
          next.line <- remaining.lines[which(st_touches(combined.line, remaining.lines, sparse = FALSE))[1],]
          
          combined.line <- st_union(combined.line, next.line)%>%
            st_cast("LINESTRING")
          
          ids <- c(ids, next.line$id)
          
          merged <- merged + 1
          print(paste0("Combined ",merged," lines"))
        }
        
        
      } else {
        connected <- TRUE
      }
    }
    
    
    
    # Collapse to multilinestring
    ml <- outer_lines_sf%>%
      summarise()
    
    # Explode back to linestring
    ls <- st_intersection(ml,ml)%>%
      st_cast("LINESTRING")
    
    
    # Convert to polygon
    polygon <- ml%>%
      st_polygonize()
    
    # Visualize polygon
    ggplot()+
      geom_sf(data = polygon, fill = "lightblue")+
      geom_sf(data = ml, color = "black", linewidth = 2)+
      theme_minimal()
    
    
    
    
    coords <- as.data.frame(st_coordinates(ml))%>%
      mutate(row = row_number())%>%
      st_as_sf(coords = c("X","Y"), crs = 4326, remove = FALSE)
    
    fl <- coords%>%
      filter(row == 1 | row == max(row))%>%
      mutate(vertex = c("First","Last"))
    
    
    
    # Reorder lines
    p.1 <- 
      
      
      
      ggplot(ml)+
      geom_sf(color = "black", linewidth = 2)+
      geom_sf(data = fl, aes(color = vertex), size = 4)+
      scale_color_manual(values = c("First" = "green", "Last" = "red"))
    
    
    st_polygonize()%>%
      mutate(Neighborhood = element$tags$name,
             osm_id = element$id,
             county_fips = county$GEOID)%>%
      st_make_valid()
    
    county.neighborhoods <- rbind(county.neighborhoods, polygon)
    
    print(paste0("Completed ",neighborhood," neighborhoods"))
    
  }
  
  # Write to GeoPackage with layer name based on county FIPS code
  layer_name <- as.character(county$GEOID)
  st_write(county.neighborhoods, paste0("Data/OSM_Neighborhoods/",county$STUSPS,".gpkg"), layer = layer_name, append = FALSE)
}


ggplot()+
  geom_sf(data = polygon, fill = "lightblue")+
  geom_sf(data = ms, linewidth = 2)+
  #geom_sf(data = pts, color = "red", size = 2)+
  theme_minimal()

