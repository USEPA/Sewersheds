# Perform Routing Between h3 hexagons and treatment plants

library(dplyr)
library(tidyr)
library(stringr)
library(h3)
library(igraph)
library(vroom)

# Load state
st.fips <- Sys.getenv("VAR")
#st.fips <- "44"

start.i <- as.numeric(Sys.getenv("START_I"))

end.i <- as.numeric(Sys.getenv("END_I"))

print(paste0("Starting ",st.fips," @ ", round(Sys.time())))

# Load h3 indexes
ep.h3.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",
                                            full.names = TRUE),
                          file = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs"))%>%
  mutate(state_code = substr(file,6,7))%>%
  filter(state_code == st.fips)

h3.df <- vroom(ep.h3.files$path, col_types = c("Near_CWNS"="c"))


# Load roads to hex
osm.file <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/OSM_to_Hex/outputs", full.names = TRUE),
                     file = list.files("/work/GRDVULN/sewershed/Data_Prep/OSM_to_Hex/outputs", full.names = FALSE))%>%
  separate(file, into = c("a","b"), sep = "_", remove = FALSE)%>%
  mutate(state_code = str_replace(b,".csv",""))%>%
  filter(state_code == st.fips)

osm.df <- vroom(osm.file$path)

# Load buildings
bldg.file <- list.files("/work/GRDVULN/sewershed/Data_Prep/02_Footprints_to_Hex/outputs", full.names = TRUE,
                        pattern = st.fips)

bldg.h3 <- vroom(bldg.file)%>%
  group_by(h3_index)%>%
  summarise(Buildings = n())

# Load census data
census.file <- list.files("/work/GRDVULN/sewershed/Data_Prep/03_Weight_Blocks/outputs", full.names = TRUE,
                          pattern = st.fips)

census.df <- vroom(census.file)%>%
  mutate(Pop_W = Population * weight,
         THU_W = THU*weight,
         Urban_W = Urban_Pop * weight)%>%
  group_by(h3_index)%>%
  summarise(Pop_W = sum(Pop_W,na.rm = TRUE),
            THU_W = sum(THU_W,na.rm = TRUE),
            Urban_W = sum(Urban_W,na.rm = TRUE))

# Create data frame of variables to summarize
vars.df <- census.df%>%
  left_join(bldg.h3)

print(paste0("Data Loaded ",st.fips," @ ", round(Sys.time())))

# TESTING
#h3_indices <- hex.all$h3_index
#end_point <- ep.df$h3_index[n]
#units <- "nodes"

# Define function
hex_dist <- function(h3_indices = NA, 
                     end_point = NA,
                     units = "nodes"){
  
  # Create a data frame of h3 indices and assign a unique number to each
  hex.nmbr <- data.frame(h3_index = c(end_point,h3_indices))%>%
    mutate(node = row_number())
  
  # Create data frame of variables to nodes
  node.vars <- hex.nmbr%>%
    left_join(vars.df)
  
  # Replicate each row 7 times
  hex.nmbr.rep <- hex.nmbr[rep(row.names(hex.nmbr), each = 7),]
  
  # Retrieve neighbors and assign as new column
  hex.nmbr.rep$neighbor <- unlist(lapply(hex.nmbr$h3_index,
                                         function(x) k_ring(x, 1)))
  
  # Filter out self-intersections
  hex.nmbr.rep.f1 <- hex.nmbr.rep%>%
    filter(!neighbor == h3_index)
  
  # Drop hexagons not in the provided indices
  hex.nmbr.rep.f2 <- hex.nmbr.rep.f1%>%
    dplyr::filter(neighbor %in% hex.nmbr$h3_index)
  
  # Join node IDs and use them to remove duplicates
  hex.nmbr.rep.f3 <- hex.nmbr.rep.f2%>%
    left_join(hex.nmbr, by = c("neighbor" = "h3_index"))%>%
    mutate(from = ifelse(node.x < node.y, node.x, node.y),
           to = ifelse(node.x < node.y, node.y, node.x))%>%
    select(from, to)%>%
    distinct()
  
  # Create the igraph network
  edges.str <- paste(paste(hex.nmbr.rep.f3$from,
                           hex.nmbr.rep.f3$to,
                           sep = ","), collapse = ",")
  
  edges.numeric <- as.numeric(read.table(text = edges.str, sep = ","))
  
  g <- make_graph(edges = edges.numeric, directed = FALSE)
  
  root.nodes <- unique(c(hex.nmbr.rep.f3$from, hex.nmbr.rep.f3$to))
  root.nodes <- root.nodes[-1]
  
  routes <- shortest_paths(g, from = 1, to = root.nodes, mode = "out")
  routes.v <- routes$vpath # list of vertex paths
  
  # Distance is the number of nodes in each list minus 1
  lengths <- unlist(lapply(routes.v, function(x) length(x)-1))
  
  # Create output dataset
  results <- data.frame(node = root.nodes,
                        M_Distance = lengths)%>%
    left_join(hex.nmbr)%>%
    select(h3_index,node,M_Distance)%>%
    mutate(Pop_B = NA,
           THU_B = NA,
           Urban_B = NA,
           Bldgs_B = NA)
  
  # For every route, compute 'in-between' stats
  for(i in 1:length(routes.v)){
    nodes <- as.numeric(routes.v[[i]])
    
    # Get h3 indexes of nodes
    node.filt <- hex.nmbr%>%
      filter(node %in% nodes)
    
    vars.filt <- vars.df%>%
      filter(h3_index %in% node.filt$h3_index)
    
    results$Pop_B[i] <- sum(vars.filt$Pop_W)
    results$THU_B[i] = sum(vars.filt$THU_W)
    results$Urban_B[i] <- sum(vars.filt$Urban_W)
    results$Bldgs_B[i] <- sum(vars.filt$Buildings)
    
  }
  
  if(units == "meters"){
    results$M_Distance <- results$M_Distance * 351.1464
  }
  
  return(results)
}



# iterate over each endpoint in the state to calculate routes
# The hexagons considered for the route either have roads or are within 5 hexagons of the endpoint

ep.df <- h3.df%>%
  filter(IS_EP == TRUE)

# If the data is split up, make sure the end row index is not greater than the total number of rows
if(end.i>nrow(ep.df)){end.i <- nrow(ep.df)}

ep.df <- ep.df[start.i:end.i,]

print(paste0("Starting to iterate routes for ",nrow(ep.df)," endpoints @ ", round(Sys.time())))

# s <- Sys.time()
# all.routes <- data.frame()
# for(n in 1:nrow(ep.df)){
#   
#   # Get hexagons within 30 km of endpoint & Filter to roads
#   hex.close <- h3.df%>%
#     filter(Near_CWNS == ep.df$Near_CWNS[n])%>%
#     filter(h3_index %in% osm.df$h3_index)%>%
#     select(h3_index, Near_CWNS)
#   
#   # Get neighbors of endpoint hexagon within a radius of 5 
#   nbrs.5 <- data.frame(h3_index = k_ring(ep.df$h3_index[n],5),
#                        Near_CWNS = ep.df$Near_CWNS[n])
#   
#   # Combine and drop endpoint
#   hex.all <- rbind(hex.close,nbrs.5)%>%
#     distinct()%>%
#     filter(!h3_index == ep.df$h3_index[n])
#   
#   
#   # Perform network distance calculation
#   routes <- hex_dist(h3_indices = hex.all$h3_index, 
#                        end_point = ep.df$h3_index[n],
#                        units = "nodes")%>%
#     mutate(Near_CWNS = ep.df$Near_CWNS[n])
#   
#   all.routes <- rbind(all.routes,routes)
# }
# 
# e <- Sys.time()
# 
# print(paste0("Iterator took ",round(difftime(e,s,units = "secs"))," seconds"))
# 296 seconds




# Evaluate speed of rbind vs speed of writing files for each iteration

# Create directory
dir.create(file.path("/work/GRDVULN/sewershed/Data_Prep/Routing/outputs",paste0("FP_",st.fips)), showWarnings = FALSE)

s <- Sys.time()
for(n in 1:nrow(ep.df)){
  
  # Get hexagons within 30 km of endpoint & Filter to roads
  hex.close <- h3.df%>%
    filter(Near_CWNS == ep.df$Near_CWNS[n])%>%
    filter(h3_index %in% osm.df$h3_index)%>%
    select(h3_index, Near_CWNS)
  
  # Get neighbors of endpoint hexagon within a radius of 5 
  nbrs.5 <- data.frame(h3_index = k_ring(ep.df$h3_index[n],5),
                       Near_CWNS = ep.df$Near_CWNS[n])
  
  # Combine and drop endpoint
  hex.all <- rbind(hex.close,nbrs.5)%>%
    distinct()%>%
    filter(!h3_index == ep.df$h3_index[n])
  
  
  # Perform network distance calculation
  routes <- hex_dist(h3_indices = hex.all$h3_index, 
                     end_point = ep.df$h3_index[n],
                     units = "nodes")%>%
    mutate(Near_CWNS = ep.df$Near_CWNS[n])
  
  vroom_write(routes, paste0("/work/GRDVULN/sewershed/Data_Prep/Routing/outputs/FP_",st.fips,"/CWNS_",ep.df$Near_CWNS[n],".csv"), delim = ",",
              append = FALSE)
  
  if(n %% 10 == 0){
    print(paste0("Completed ", n, " routes (", round(100*(n/nrow(ep.df))),"%)", " --- ",round(Sys.time())))
  }
  
}

e <- Sys.time()

print(paste0("Processing Completed in ",round(difftime(e,s,units = "mins"))," minutes"))
# 303 seconds

print(paste0("SCRIPT COMPLETE @ ",round(Sys.time())))















# Save file
# vroom_write(all.routes, paste0("/work/GRDVULN/sewershed/Data_Prep/Routing/outputs/Route_",st.fips,".csv"),
#             delim = ",", append = FALSE)



# Attempt to run in parallel
# library(doParallel)
# 
# cores <- detectCores()-1
# print(paste0("Attempting to create cluster with ", cores, "cores..."))
# cl <- makeCluster(cores)
# registerDoParallel(cl)
# 
# s2 <- Sys.time()
# 
# routes.par <- foreach(n = 1:nrow(ep.df),.packages = c("dplyr","igraph","h3"),
#                   .combine=rbind) %dopar%{
#                     
#                     # Get hexagons within 30 km of endpoint & Filter to roads
#                     hex.close <- h3.df%>%
#                       filter(Near_CWNS == ep.df$Near_CWNS[n])%>%
#                       filter(h3_index %in% osm.df$h3_index)%>%
#                       select(h3_index, Near_CWNS)
#                     
#                     # Get neighbors of endpoint hexagon within a radius of 5 
#                     nbrs.5 <- data.frame(h3_index = k_ring(ep.df$h3_index[n],5),
#                                          Near_CWNS = ep.df$Near_CWNS[n])
#                     
#                     # Combine and drop endpoint
#                     hex.all <- rbind(hex.close,nbrs.5)%>%
#                       distinct()%>%
#                       filter(!h3_index == ep.df$h3_index[n])
#                     
#                     
#                     # Perform network distance calculation
#                     routes <- hex_dist(h3_indices = hex.all$h3_index, 
#                                        end_point = ep.df$h3_index[n],
#                                        units = "nodes")%>%
#                       mutate(Near_CWNS = ep.df$Near_CWNS[n])
#                     
#                     return(routes)
#                     
#                   }
# 
# e2 <- Sys.time()
# 
# print(paste0("Parallel foreach took ",round(difftime(e2,s2,units = "secs"))," seconds"))
# 470 seconds 
