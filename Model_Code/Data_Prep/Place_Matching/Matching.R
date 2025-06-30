library(dplyr)
library(stringr)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
library(vroom)
library(sf)
library(stringdist)

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- '44'

print(paste0("Loading Data @ ", round(Sys.time())))

# Load H3 Hexagons
h3.df <- vroom(list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/H3_Tables",
                          pattern = st.fips,full.names = TRUE), col_types = c("Near_CWNS"="c"))

# Load Place Joins
hex.place <- vroom(paste0("/work/GRDVULN/sewershed/Data_Prep/Place_to_H3/outputs/FP_",st.fips,".csv"))

# Load Sub-County joins
hex.subcounty <- vroom(paste0("/work/GRDVULN/sewershed/Data_Prep/SubCounty_to_H3/outputs/FP_",st.fips,".csv"))

# Load County joins
cnty.names <- st_read("/work/GRDVULN/sewershed/Data/US_county_2022.shp")%>%
  st_drop_geometry()%>%
  select(GEOID,NAME)%>%
  setNames(c("GEOID","County"))
hex.county <- vroom(paste0("/work/GRDVULN/sewershed/Data_Prep/H3_Counties/outputs/ST_",st.fips,".csv"),
                    col_types = c("CoFIPS"="c"))%>%
  left_join(cnty.names, by = c("CoFIPS"="GEOID"))%>%
  select(h3_index,County)

print(paste0("Loading CWNS Data @ ", round(Sys.time())))

# Load Physical Location
locations <- vroom("/work/GRDVULN/sewershed/Data/PHYSICAL_LOCATION.txt")%>%
  select(CWNS_ID,CITY)%>%
  distinct()

# Load CWNS Facility Names
facilities <- vroom("/work/GRDVULN/sewershed/Data/FACILITIES.txt")%>%
  select(CWNS_ID,FACILITY_NAME)%>%
  left_join(locations)

# Using the Near_CWNS field, join the places, subcounties and city names to complete fuzzy matching
h3.matching <- h3.df%>%
  select(h3_index,Near_CWNS)%>%
  left_join(facilities, by = c("Near_CWNS"="CWNS_ID"))%>%
  left_join(hex.place, by = "h3_index")%>%
  left_join(hex.subcounty, by = "h3_index")%>%
  left_join(hex.county, by = "h3_index")%>%
  mutate(FACILITY_NAME = iconv(FACILITY_NAME, "UTF-8", "UTF-8",sub=''),
         FACILITY_NAME = tolower(FACILITY_NAME),
         CITY = tolower(CITY),
         Place = tolower(Place),
         SubCounty = tolower(SubCounty),
         County = tolower(County))
  
# Get unique rows for faster computation
match.distinct <- h3.matching%>%
  select(!h3_index)%>%
  distinct()

print(paste0("Calculating Match Scores @ ", round(Sys.time())))

# Identify non-utf8 characters
# utf8.replace <- match.distinct%>%
#   mutate(FACILITY_NAME = iconv(FACILITY_NAME, "UTF-8", "UTF-8",sub=''))


jaccard <- match.distinct%>%
  mutate(City_Place = stringdist(CITY,Place,method = "jaccard"),
         City_SubCounty = stringdist(CITY,SubCounty,method = "jaccard"),
         City_County = stringdist(CITY,County,method = "jaccard"),
         Name_Place = stringdist(FACILITY_NAME,Place,method = "jaccard"),
         Name_SubCounty = stringdist(FACILITY_NAME,SubCounty,method = "jaccard"),
         Name_County = stringdist(FACILITY_NAME,County,method = "jaccard"))%>%
  rowwise() %>%
  mutate(Match_Score = min(City_Place, City_SubCounty, City_County,
                           Name_Place,Name_SubCounty,Name_County,na.rm = TRUE))%>%
  ungroup()%>%
  mutate(Match_Type = NA)

for(i in 1:nrow(jaccard)){
  row <- jaccard[i,]
  
  m.type <- which(row == row$Match_Score)[1]
  
  jaccard$Match_Type[i] <- colnames(jaccard)[m.type]
  
}
  

# lcs.adjust <- match.distinct%>%
#   mutate(CP_Length = ifelse(nchar(CITY)<nchar(Place),nchar(CITY),nchar(Place)),
#          CS_Length = ifelse(nchar(CITY)<nchar(SubCounty),nchar(CITY),nchar(SubCounty)),
#          NP_Length = ifelse(nchar(FACILITY_NAME)<nchar(Place),nchar(FACILITY_NAME),nchar(Place)),
#          NS_Length = ifelse(nchar(FACILITY_NAME)<nchar(SubCounty),nchar(FACILITY_NAME),nchar(SubCounty)),
#          City_Place = stringdist(CITY,Place,method = "lcs"),
#          City_Place_Adj = City_Place - CP_Length,
#          City_SubCounty = stringdist(CITY,SubCounty,method = "lcs"),
#          Name_Place = stringdist(FACILITY_NAME,Place,method = "lcs"),
#          Name_SubCounty = stringdist(FACILITY_NAME,SubCounty,method = "lcs"))%>%
#   rowwise() %>%
#   mutate(Match_Score = min(City_Place, City_SubCounty,Name_Place,Name_SubCounty,na.rm = TRUE))

# Join matches back to h3.matching
h3.matched <- h3.matching%>%
  left_join(jaccard, by = c("Near_CWNS", "FACILITY_NAME", "CITY", "Place", "SubCounty","County"))%>%
  distinct()
print(paste0("Saving Data @ ", round(Sys.time())))

vroom_write(h3.matched,paste0("/work/GRDVULN/sewershed/Data_Prep/Place_Matching/outputs/STFP_",st.fips,".csv"), delim = ",", append = FALSE)

print(paste0("SCRIPT COMPLETE @ ", round(Sys.time())))
