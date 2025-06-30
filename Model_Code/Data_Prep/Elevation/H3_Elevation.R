library(sf)
library(vroom)
library(tidyverse)
library(elevatr)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
#library(doParallel)

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")

print(paste0("Starting: ",st.fips," @ ",round(Sys.time())))

# Load Hexagons
hex.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",
                                          full.names = TRUE),
                        file = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs"))%>%
  mutate(state_code = substr(file,6,7))%>%
  filter(state_code == st.fips)

hex.df <- read_tsv(hex.files$path)

h3 <- unique(hex.df$h3_index)

# Get centroids of H3 Hexagons
centers <- as.data.frame(h3_to_geo(h3))%>%
  setNames(c("y","x"))%>%
  select(x,y)
print(paste0("Querying Elevation Data for ",format(nrow(centers),big.mark = ",")," hexagons @ ",round(Sys.time())))



# Download in chunks of 50,000
nChunks <- ceiling(nrow(centers)/50000)

print(paste0("Downloading in ",nChunks," chunks of 50,000 (Max)"))
start.i <- 1
end.i <- 50000

for(c in 1:nChunks){
  chunk.subset <- centers[start.i:end.i,]
  
  s <- Sys.time()
  pt.elev <- get_elev_point(chunk.subset, prj = 4326)
  e <- Sys.time()
  
  # Sometimes the query service faulters and we need to check for missing data:
  check.na <- pt.elev%>%
    filter(is.na(elevation))
  
  if(nrow(check.na) > 0){
    print(paste0("Failed to retrieve elevation for ",nrow(check.na)," hexagons ... Trying up to 10 more times..."))
    
    
    n <- 1
    while(length(which(is.na(pt.elev$elevation))) > 0 && n <= 10) {
      message("Retrying elevation retrieval, attempt ", n)
      # Identify row numbers of missing elevation
      missing <- which(is.na(pt.elev$elevation)) # Find missing elevations
      retry <- get_elev_point(select(pt.elev[missing,],!c(elevation,elev_units)), prj = 4326)
      # Update missing data
      pt.elev$elevation[missing] <- retry$elevation
      n <- n + 1
    }
    
    print(paste0("Retrieved ", nrow(check.na) - length(which(is.na(pt.elev$elevation)))," additional hexagons after ",n-1," additional tries ... ",
                 length(which(is.na(pt.elev$elevation)))," could not be retrieved."))
    
  }
  
  
  # Save output
  chunk.subset$elevation <- pt.elev$elevation
  chunk.subset$h3_index <- h3[start.i:end.i]
  
  # Save output
  elev.out <- chunk.subset%>%
    select(h3_index,elevation)%>%
    setNames(c("h3_index","elevation_m"))
  
  vroom_write(elev.out,paste0("/work/GRDVULN/sewershed/Data_Prep/Elevation/outputs/H3_Elev_",st.fips,"_",c,".csv"),
              delim = ",", append = FALSE)
  
  
  # Increase start and end indices
  start.i <- start.i + 50000
  if(start.i == 50001){start.i <- 50000}
  #print(start.i)
  end.i <- end.i+50000
  if(end.i == 100000){end.i <- 99999}
  #print(end.i)
  
  if(end.i>nrow(centers)){end.i <- nrow(centers)}
  
  print(paste0("Completed Chunk #",c," @ ",round(Sys.time())))
  
}


# s <- Sys.time()
# pt.elev <- get_elev_point(centers, prj = 4326)
# e <- Sys.time()
# 
# print("SUCCESS!")
# print(paste0("1st try at elevation downloaded in ",round(as.numeric(difftime(e,s,units = "mins")),1)," minutes"))
# 
# 
# # Sometimes the query service faulters and we need to check for missing data:
# check.na <- pt.elev%>%
#   filter(is.na(elevation))
# 
# if(nrow(check.na) > 0){
#   print(paste0("Failed to retrieve elevation for ",nrow(check.na)," hexagons ... Trying up to 10 more times..."))
#   
#   
#   n <- 1
#   while(length(which(is.na(pt.elev$elevation))) > 0 && n <= 10) {
#     message("Retrying elevation retrieval, attempt ", n)
#     # Identify row numbers of missing elevation
#     missing <- which(is.na(pt.elev$elevation)) # Find missing elevations
#     retry <- get_elev_point(select(pt.elev[missing,],!c(elevation,elev_units)), prj = 4326)
#     # Update missing data
#     pt.elev$elevation[missing] <- retry$elevation
#     n <- n + 1
#   }
#   
#   print(paste0("Retrieved ", nrow(check.na) - length(which(is.na(pt.elev$elevation)))," additional hexagons after ",n-1," additional tries ... ",
#                length(which(is.na(pt.elev$elevation)))," could not be retrieved."))
#   
# }
# 
# 
# # Save output
# centers$elevation <- pt.elev$elevation
# centers$h3_index <- h3
# 
# # Save output
# elev.out <- centers%>%
#   select(h3_index,elevation)%>%
#   setNames(c("h3_index","elevation_m"))
# 
# vroom_write(elev.out,paste0("/work/GRDVULN/sewershed/Data_Prep/Elevation/outputs/H3_Elev_",st.fips,".csv"),
#             delim = ",", append = FALSE)
# 
# 
# print(paste0("Completed: ",st.fips," @ ",round(Sys.time())))