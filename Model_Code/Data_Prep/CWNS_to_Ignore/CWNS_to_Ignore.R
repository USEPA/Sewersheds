# This creates the list of systems we need to ignore for the time-being

library(tidyverse)
library(vroom)
library(sf)

# Load endpoint locations and find duplicates
ep <- vroom("/work/GRDVULN/sewershed/Data/endpoint_coords_moved_03132025.csv")%>%
  mutate(LL = paste0(Lat,"_",Lon),
         Ignore = FALSE)

dups <- as.data.frame(table(ep$LL))%>%
  filter(Freq > 1)

dups.idx <- which(ep$LL %in% dups$Var1)

ep$Ignore[dups.idx] <- TRUE


# If the treatment plant is in the Population_Wastewater_Confirmed table and receives discharge from an upstream treatment plant.
dcharge <- vroom("/work/GRDVULN/sewershed/Data/DISCHARGES.csv", col_names = c("CWNS_ID","FACILITY_ID","STATE_CODE","DISCHARGE_TYPE",
                                                                              "PRESENT_DISCHARGE","PRJ_DISCHARGE","DISCHARGES_TO_CWNS_ID"))

pop.w <- vroom("/work/GRDVULN/sewershed/Data/POPULATION_WASTEWATER_CONFIRMED_updated06242024.csv")

d.filt <- pop.w%>%
  filter(CWNS_ID %in% dcharge$DISCHARGES_TO_CWNS_ID)


# Filter missing 2 CWNS_IDs because the pop wastewater confirmed table was appended, but we'll also ignore these additional 2 for the time being.
l <- c("06001017001",
       "06004018001",
       "06005256001",
       "28000535001",
       "32000000017",
       "32000039001",
       "32000200801",
       "41000064001",
       "42003015001",
       "42003125002",
       "42003126001",
       "42005097001",
       "42006014001",
       "42006125001",
       "42006131001",
       "45000104002",
       "45000237002",
       "45000298001",
       "45000612001"
)

l %in% d.filt$CWNS_ID

d.idx <- which(ep$CWNS_ID %in% l)

ep$Ignore[d.idx] <- TRUE

to.ignore <- ep%>%
  filter(Ignore == TRUE)

write.csv(to.ignore, "/work/GRDVULN/sewershed/Data_Prep/CWNS_to_Ignore/to_ignore.csv", row.names = FALSE)
