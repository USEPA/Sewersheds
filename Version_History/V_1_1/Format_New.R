library(vroom)
library(tidyverse)
library(here)
library(sf)

# Load new sewersheds
new <- st_read(here("Version_History/V_1_1/New_Weighted.gpkg"), layer = "Sewersheds")

# Load CWNS Data
names <- vroom(here("Data/FACILITIES.txt"))%>%
  select(CWNS_ID,FACILITY_NAME)

city <- vroom(here("Data/PHYSICAL_LOCATION.txt"))%>%
  select(CWNS_ID,CITY)

pop <- vroom(here("Data/POPULATION_WASTEWATER.txt"))%>%
  select(CWNS_ID,RESIDENTIAL_POP_2022,TOTAL_RES_POPULATION_2022)

new.format <- new%>%
  left_join(names, by = "CWNS_ID")%>%
  left_join(city, by = "CWNS_ID")%>%
  left_join(pop, by = "CWNS_ID")%>%
  select(CWNS_ID,FACILITY_NAME,Est_Population,Buildings,Method,state_code,CITY,RESIDENTIAL_POP_2022,TOTAL_RES_POPULATION_2022)%>%
  setNames(c("CWNS_ID","POTW Name","2020 Population","Building Count","Method","State","City","Residential_Pop_2022","Total_Res_Pop_2022","geom"))

st_write(new.format, here("Version_History/V_1_1/V_1_1_Format.gpkg"),layer = "Sewersheds")
