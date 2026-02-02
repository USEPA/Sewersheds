library(sf)
library(dplyr)
library(stringr)
library(here)

# Establish Version Number
version <- "1.1"


# Chicago
chicago.files <- list.files(here("Data/State_Provided_Data/Chicago"),
                            full.names = TRUE, recursive = TRUE, pattern = ".shp$")

chicago.cwnsids <- c("UPPER DUPAGE RIVER BASIN" = "17000721002",
  "POPLAR CREEK BASIN" = "17000643001",
  "UPPER SALT CREEK BASIN" = "17000721005",
  "OHARE BASIN" = "17000721006",
  "NORTH SIDE BASIN" = "17000721007",
  "CENTRAL BASIN" = "17000721001",
  "SOUTH BASIN" = "17000721009",
  "LEMONT BASIN" = "17000721008")%>%
  stack()%>%
  setNames(c("CWNS_ID","name"))
chicago.sf <- data.frame()
for(n in 1:length(chicago.files)){
  next.sf <- st_read(chicago.files[n])%>%
    select(name)
  chicago.sf <- rbind(chicago.sf,next.sf)
}

chicago.cwns <- chicago.sf%>%
  left_join(chicago.cwnsids, by = "name")%>%
  st_transform(st_crs(4326))%>%
  st_make_valid()%>%
  mutate(Method = "Utility Sourced",
         Version_Added = version,
         Date_Added = lubridate::today())%>%
  select(CWNS_ID,Method,Date_Added,Version_Added)

# Digitized List digitized files
digitized.layers <- st_layers("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Github/Sewersheds/Data/Digitized/Sewersheds.gdb")$name

digitized.sf <- data.frame()

for(n in 1:length(digitized.layers)){
  next.sf <- st_read("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Github/Sewersheds/Data/Digitized/Sewersheds.gdb",
                     layer = digitized.layers[n])%>%
    mutate(CWNS_ID = str_replace(digitized.layers[n],"CWNS_",""))%>%
    select(CWNS_ID)%>%
    st_transform(st_crs(4326))%>%
    st_make_valid()
  
  digitized.sf <- rbind(digitized.sf,next.sf)
}
colnames(digitized.sf) <- c("CWNS_ID","geometry")
st_geometry(digitized.sf) <- "geometry"

digitized.format <- digitized.sf%>%
  mutate(Method = "Utility Sourced",
         Version_Added = version,
         Date_Added = lubridate::today())%>%
  select(CWNS_ID,Method,Date_Added,Version_Added)


# Submitted
submitted.sf <- st_read("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Github/Sewershed_Feedback_Tracker/downloads/Uploads.gpkg",
                        layer = "Uploads_01212026")%>%
  group_by(cwns_id)%>%
  summarise()%>%
  setNames(c("CWNS_ID","geometry"))
st_geometry(submitted.sf) <- "geometry"

submitted.format <- submitted.sf%>%
  mutate(Method = "Submitted",
         Version_Added = version,
         Date_Added = lubridate::today())%>%
  select(CWNS_ID,Method,Date_Added,Version_Added)

# Other (email etc...)
# Greensboro
gbo <- st_read("C:/Users/AMURRA02/OneDrive - Environmental Protection Agency (EPA)/Github/Sewersheds/Data/State_Provided_Data/Greensboro_WWTP/Greensboro_WWTP/Greensboro_WWTP.shp")%>%
  summarise()%>%
  mutate(CWNS_ID = "24000039001",
         Version_Added = version,
         Method = "Utility Sourced",
         Date_Added = lubridate::today())%>%
  st_transform(st_crs(4326))%>%
  st_make_valid()%>%
  select(CWNS_ID,Method,Date_Added,Version_Added)

# Merge then save

new.sewersheds <- bind_rows(chicago.cwns,digitized.format,submitted.format,gbo)

st_write(new.sewersheds,here("Version_History/V_1_1/New.gpkg"), layer = "Sewersheds",
         append = FALSE)

