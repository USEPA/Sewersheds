library(sf)
library(tisyverse)
library(osmdata)
library(h3)



# Select a county
county <- tigris::counties()%>%
  filter(NAME == "Pendleton" & STATEFP == "21")


# Create grid to get H3 Hexagons
grid <- county%>%
  st_transform(st_crs(5070))%>%
  st_make_grid(250, what = "centers")%>%
  st_transform(st_crs(4326))%>%
  st_sf()

coords <- as.data.frame(st_coordinates(grid))

h3 <- unique(geo_to_h3(c(coords$Y, coords$X), res = 9))

# Get H3 polygons
s <- Sys.time()
h3.sf <- h3_to_geo_boundary_sf(h3)
e <- Sys.time()

plot(st_geometry(h3.sf)[1])




# H3_build_network
# Builds a hexagon network by determining the types of roads that
# link neighboring hexagons. This function requires a character vector
# of hexagon IDs and an sf object of roads from Open Street Map


h3_build_network <- function(h3, roads = NULL){
  
  # Create sf dataset with empty geometries to write to
  sf <- st_sf(root = rep(h3,each = 6),
        neighbor = NA,
        edgeID = NA,
        geometry = st_sfc(lapply(1:(length(h3)*6), function(x) st_linestring()),crs = st_crs(4326)))
  
  # Iterate through each hexagon
  
  ## Create start and end row IDs
  row.s <- 1
  row.e <- 6
  
  for(n in 1:length(h3)){
    
    # Get neighbors
    neighbors <- k_ring(h3[n],1)[!grepl(h3[n],k_ring(h3[n],1))]
    
    # Write neighbors to sf
    sf$neighbor[n:(n+5)] <- neighbors
    
    
    edge.1 <- get_h3_unidirectional_edge(h3[n],neighbors[1])
    edge.2 <- get_h3_unidirectional_edge(h3[n],neighbors[2])
    edge.3 <- get_h3_unidirectional_edge(h3[n],neighbors[3])
    edge.4 <- get_h3_unidirectional_edge(h3[n],neighbors[4])
    edge.5 <- get_h3_unidirectional_edge(h3[n],neighbors[5])
    edge.6 <- get_h3_unidirectional_edge(h3[n],neighbors[6])
    
    sf$edgeID[row.s] <- edge.1
    sf$edgeID[row.s+1] <- edge.2
    sf$edgeID[row.s+2] <- edge.3
    sf$edgeID[row.s+3] <- edge.4
    sf$edgeID[row.s+4] <- edge.5
    sf$edgeID[row.s+5] <- edge.6
    
    # Write geometries to sf
    edge.sf.1 <- get_h3_unidirectional_edge_boundary_sf(edge.1)
    edge.sf.2 <- get_h3_unidirectional_edge_boundary_sf(edge.2)
    edge.sf.3 <- get_h3_unidirectional_edge_boundary_sf(edge.3)
    edge.sf.4 <- get_h3_unidirectional_edge_boundary_sf(edge.4)
    edge.sf.5 <- get_h3_unidirectional_edge_boundary_sf(edge.5)
    edge.sf.6 <- get_h3_unidirectional_edge_boundary_sf(edge.6)
    
    sf$geometry[row.s] <- edge.sf.1$geometry
    sf$geometry[row.s+1] <- edge.sf.2$geometry
    sf$geometry[row.s+2] <- edge.sf.3$geometry
    sf$geometry[row.s+3] <- edge.sf.4$geometry
    sf$geometry[row.s+4] <- edge.sf.5$geometry
    sf$geometry[row.s+5] <- edge.sf.6$geometry
    
    # Increase start and end row
    row.s <- row.s + 6
    row.e <- row.e + 6
      
    }
  
  
  
  return(sf)
  
}


## Testing with subset of 5 hexagons
temp <- h3[1:100]

test <- h3_build_network(temp)

ggplot(test)+
  geom_sf(aes(color = edgeID))


# Time performance
time.out <- data.frame()
for(t in c(10,100,500,1000,1500,2000,3000,4000,5000)){
  
  temp <- h3[1:t]
  
  start <- Sys.time()
  test <- h3_build_network(temp)
  end <- Sys.time()
  
  seconds <- difftime(end,start,units = "secs")
  
  newRow <- data.frame(Hexagons = t, Seconds = seconds)
  time.out <- rbind(time.out,newRow)
  
  print(paste0("Completed ",t," hexagons in ",seconds," seconds"))
}

ggplot(time.out)+
  geom_point(aes(x = Hexagons, y = Seconds))+
  geom_smooth(aes(x = Hexagons, y = Seconds), method = "lm")+
  labs(title = "Time to Build Network by Number of Hexagons",
       x = "Number of Hexagons",
       y = "Seconds")


