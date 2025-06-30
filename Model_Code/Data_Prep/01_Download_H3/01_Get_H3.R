# This script will determine which h3 hexagons endpoints are in and the hexagons
# that are within 32 kilometers of the endpoint.

#library(h3r)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
library(sf)
library(dplyr)
library(tidyr)
library(doParallel)
library(vroom)

# Set Resolution
res <- 9

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")

print(paste0("Starting ",st.fips," @ ", round(Sys.time())))

# Load fips join
# fips.join <- vroom("/work/GRDVULN/sewershed/Data/fips_join.csv")%>%
#   filter(state == st.fips)

# Load endpoints for the state
ep <- vroom("/work/GRDVULN/sewershed/Data/endpoints_04032025.csv")%>%
  filter(substr(CWNS_ID,1,2)==st.fips)

# Fetch H3 IDs
ep$h3_index <- geo_to_h3(c(ep$Y,ep$X),9)
  
# Create column to denote Near CWNS_ID
ep$Near_CWNS <- ep$CWNS_ID

# Label as endpoint location
ep$IS_EP = TRUE

# Iterate through rows to retrieve neighbors
k_rings <- ep%>%
  mutate(distance = 0)%>%
  select(h3_index,distance,Near_CWNS,IS_EP)

cores <- detectCores()-1
cl <- makeCluster(cores)
registerDoParallel(cl)

# Time parallel
s.1 <- Sys.time()

h3.out <- foreach(n = 1:nrow(k_rings),
        .packages = c("dplyr","tidyr"), .combine = 'rbind') %dopar%{
          
          library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
          
          # Identify h3 index of endpoint
          ep.h3 <- k_rings$h3_index[n]
          
          # Fetch neighbors out to ~32 km, which is roughly 90 hexagons 
          neighbors <- k_ring_distances(ep.h3,radius = 90)
          
          # Create rows and remove the root hex (its a duplicate)
          newRows <- neighbors%>%
            mutate(Near_CWNS = k_rings$Near_CWNS[n],
                   IS_EP = FALSE)%>%
            filter(!h3_index == k_rings$h3_index[n])
          
          return(newRows)
        }

s.2 <- Sys.time()

elapsed <- round(as.numeric(difftime(s.2,s.1,units = "mins")),2)
stopCluster(cl)

print(paste0("Completed ",st.fips," @ ",round(Sys.time())," --- PROCESSING TOOK: ",elapsed," MINUTES."))


# Combine endpoint hexagons with their neighborhoods
h3.all <- rbind(k_rings,h3.out)%>%
  distinct()

# Save table of hexagons
vroom_write(h3.all, paste0("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/H3_Tables/STFP_",st.fips,".csv"),
            append = FALSE)
