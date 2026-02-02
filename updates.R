library(tidyverse)
library(sf)
library(vroom)
library(here)

# Load new version
v1.1 <- st_read("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Github/Sewersheds/Version_History/V_1_1/WEBAPP_01_26_26.gdb",
                layer = "Max_Prob_Concave")%>%
  select(CWNS_ID,Method,Min_Prob,Mean_Prob,Pop_2020,Buildings,FACILITY_NAME,STATE_CODE,City,RESIDENTIAL_POP_2022,TOTAL_RES_POPULATION_2022)

colnames(v1.1)[9] <- "CITY"

# Save geopackage
st_write(v1.1,here("Version_History/V_1_1/V_1_1.gpkg"), layer = "Sewersheds")

# Load endpoints
ep <- st_read("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Github/Sewersheds/Version_History/V_1_1/WEBAPP_01_26_26.gdb",
              layer = "Endpoints")%>%
  select(CWNS_ID,FACILITY_NAME,STATE_CODE,CITY,RESIDENTIAL_POP_2022,TOTAL_RES_POPULATION_2022)
st_write(ep,here("Version_History/V_1_1/V_1_1.gpkg"), layer = "Endpoints")

# Load Added to this version
added.df <- read.csv(here("Version_History/V_1_1/Added_Sources_3.csv"))%>%
  select(!CWNS_Type)

write.csv(added.df,here("Version_History/sources.csv"),row.names = FALSE)
