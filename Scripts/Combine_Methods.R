library(tidyverse)
library(sf)



sourced <- st_read("Data/Utility_Polygons.shp")%>%
  select(CWNS_ID)%>%
  #filter(nchar(CWNS_ID) == 11)%>%
  setNames(c("CWNS_ID","geom"))
st_geometry(sourced) <- "geom"

sourced.2 <- st_read("Data/Utility_2.gpkg")%>%
  filter(!CWNS_ID %in% sourced$CWNS_ID)%>%
  filter(nchar(CWNS_ID) == 11)%>%
  select(CWNS_ID)%>%
  rbind(sourced)%>%
  mutate(Method = "Sourced")

test <- "06009031004; 06009031001; 06009031002; 06009032001"
test1 <- unlist(str_split(test,pattern = "; "))
all.sourced <- c(sourced$CWNS_ID,test1,sourced.2$CWNS_ID)
  

modeled <- st_read("Model_Results/Merged_Sewersheds.gpkg", layer = "Model")%>%
  filter(!Near_CWNS %in% all.sourced)%>%
  select(Near_CWNS,Min_Prob,Mean_Prob)%>%
  mutate(Method = "Modeled")
colnames(modeled)[1] <- "CWNS_ID"



# Load CWNS Data
cwns.1 <- vroom("Data/FACILITIES.txt")

cwns <- vroom("Data/FACILITIES_CONFIRMED.txt")%>%
  rbind(cwns.1)%>%
  select(CWNS_ID,FACILITY_ID,STATE_CODE,FACILITY_NAME)


pop.1 <- vroom("Data/POPULATION_WASTEWATER.txt")%>%
  select(CWNS_ID,TOTAL_RES_POPULATION_2022)
pop <- vroom("Data/POPULATION_WASTEWATER_CONFIRMED_updated06242024.csv")%>%
  select(CWNS_ID,TOTAL_RES_POPULATION_2022)%>%
  rbind(pop.1)

all <- bind_rows(modeled,sourced.2)%>%
  left_join(cwns, by = "CWNS_ID")%>%
  left_join(pop, by = "CWNS_ID")%>%
  select(CWNS_ID,STATE_CODE,FACILITY_NAME,FACILITY_ID,TOTAL_RES_POPULATION_2022,Method,Min_Prob,Mean_Prob)

# Remove non-UTF 8 characters
all$FACILITY_NAME <- iconv(all$FACILITY_NAME, from = "UTF-8", to = "UTF-8", sub = "")
all$FACILITY_NAME <- str_squish(all$FACILITY_NAME)

st_write(all,"Model_Results/Sewersheds.gpkg",layer = "Sewersheds_2022", append = FALSE)

st_write(all,"Model_Results/Sewersheds_Final.shp", append = FALSE)
