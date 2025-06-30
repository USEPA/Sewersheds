# When hexagons were created, we allowed them to cross state lines. This script trims those hexagons so they must
# be within the state of the endpoint.

library(tidyverse)
library(sf)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
library(vroom)

print(paste0("Script Start @ ",round(Sys.time())))

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- "44"

# Load probability file
df <- vroom(paste0("/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/tables/BoostPredictions_",st.fips,".csv"))

# Load hex to state file to limit system to within the state
state <- st_read("/work/GRDVULN/sewershed/Data/US_county_2022.shp")%>%
  filter(STATEFP == st.fips)%>%
  summarise()%>%
  st_transform(st_crs(4326))%>%
  st_make_valid()

# Intersect points to eliminate out-of-state hexagons
prob.h3 <- h3_to_geo_sf(unique(df$h3_index))

prob.state <- st_intersection(prob.h3,state)

df.st <- df%>%
  filter(h3_index %in% prob.state$h3_index)

# Save output
vroom_write(df.st, paste0("/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/tables_clip/BoostPredictions_",st.fips,".csv"),
            delim = ",", append = FALSE)

print(paste0("Trimmed from ",format(nrow(df),big.mark = ",")," rows to ",format(nrow(df.st),big.mark = ",")))

print(paste0("Finished @ ", round(Sys.time())))
