library(dplyr)
library(vroom)
library(h3)

df <- vroom("Model_Review_App/Data/Predictions.csv")

filt <- df%>%
  filter(Estimate >= 0.9 & substr(Near_CWNS,1,2) == "39")

h3 <- h3_to_geo_boundary_sf(unique(filt$h3_index))%>%
  left_join(filt)%>%
  group_by(Near_CWNS)%>%
  summarise()

pop <- vroom("Data/POPULATION_WASTEWATER.txt")%>%
  select(CWNS_ID,TOTAL_RES_POPULATION_2022)

cwns <- vroom("Data/FACILITIES.txt")%>%
  select(FACILITY_NAME,CWNS_ID,STATE_CODE)%>%
  left_join(pop)%>%
  filter(CWNS_ID %in% df$Near_CWNS)%>%
  distinct()%>%
  setNames(c("Name","CWNS_ID","State","Population"))

h3.out <- h3%>%
  left_join(cwns, by = c("Near_CWNS"="CWNS_ID"))

st_write(h3.out,"D:/temp/OH_Test.shp")
