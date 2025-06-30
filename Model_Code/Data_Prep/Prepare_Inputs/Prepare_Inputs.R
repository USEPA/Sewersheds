library(tidyverse)
library(vroom)

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- "44"

print(paste0("Beginning State: ",st.fips," @ ", round(Sys.time())))

# H3 to Endpoint Relationships
h3.ep.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",full.names = TRUE),
                          file = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",full.names = FALSE))%>%
  mutate(state = substr(file,6,7))%>%
  filter(state == st.fips)

h3.ep <- vroom(h3.ep.files$path, col_types = c("Near_CWNS"="c"))

# Load Elevation
elev.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/Elevation/merged",full.names = TRUE),
                         file = list.files("/work/GRDVULN/sewershed/Data_Prep/Elevation/merged",full.names = FALSE))%>%
  mutate(state = substr(file,4,5))%>%
  filter(state == st.fips)

elev.df <- vroom(elev.files$path)

## Determine elevation of endpoint
ep.elev <- h3.ep%>%
  filter(IS_EP == TRUE)%>%
  select(h3_index,Near_CWNS)%>%
  left_join(elev.df)%>%
  select(!h3_index)%>%
  setNames(c("Near_CWNS","EP_Elevation"))

# Load Building Stats
bldg.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/02_Footprints_to_Hex/outputs",full.names = TRUE),
                         file = list.files("/work/GRDVULN/sewershed/Data_Prep/02_Footprints_to_Hex/outputs",full.names = FALSE))%>%
  mutate(state = substr(file,6,7))%>%
  filter(state == st.fips)

h3.bldg <- vroom(bldg.files$path)%>%
  select(h3_index,Area_m,height)%>%
  mutate(height = ifelse(height < 0 , 4.9,height))%>%
  group_by(h3_index)%>%
  summarise(Med_Bldg_Height = median(height,na.rm = TRUE),
            Mean_Bldg_Height = mean(height,na.rm=TRUE),
            Med_Bldg_Area = median(Area_m,na.rm = TRUE),
            Mean_Bldg_Area = mean(Area_m,na.rm = TRUE),
            nBldgs = n())

# Load Census Data

## Crosswalked data
cw.df <- vroom("/work/GRDVULN/sewershed/Data/Blocks_2020_CW.csv")%>%
  select(GISJOIN,HU_1990,HU_2000,HU_2010,Public_S_90,Sewer_D_90)

census.weight.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/03_Weight_Blocks/outputs",full.names = TRUE),
                           file = list.files("/work/GRDVULN/sewershed/Data_Prep/03_Weight_Blocks/outputs",full.names = FALSE))%>%
  mutate(state = substr(file,13,14))%>%
  filter(state == st.fips)

census.weights <- vroom(census.weight.files$path)%>%
  left_join(cw.df)%>%
  mutate(HU_90_W = HU_1990 * weight,
         HU_20_W = THU * weight,
         Pop_W = Population * weight,
         Water_W = Public_S_90 * weight,
         Sewer_W = Sewer_D_90 * weight,
         Urban_W = Urban_Pop * weight)%>%
  group_by(h3_index)%>%
  summarise(Pop_2020 = sum(Pop_W,na.rm = TRUE),
            Urban_Pop = sum(Urban_W,na.rm = TRUE),
            HU_90 = sum(HU_90_W,na.rm = TRUE),
            HU_20 = sum(HU_20_W,na.rm=TRUE),
            Water_90 = sum(Water_W,na.rm = TRUE),
            Sewer_90 = sum(Sewer_W,na.rm = TRUE))%>%
  mutate(Pct_Water_90 = Water_90/HU_90,
         Pct_Sewer_90 = Sewer_90/HU_90,
         Pct_Urban_20 = Urban_Pop / Pop_2020,
         Pct_Urban_20 = replace_na(Pct_Urban_20,0),
         Urban_Rural = ifelse(Pct_Urban_20 > 0, "Urban","Rural"))


# Load NLCD
nlcd.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/NLCD_to_Hex/outputs",full.names = TRUE),
                         file = list.files("/work/GRDVULN/sewershed/Data_Prep/NLCD_to_Hex/outputs",full.names = FALSE))%>%
  mutate(state = substr(file,9,10))%>%
  filter(state == st.fips)

# Reclassify NLCD
nlcd.df <- vroom(nlcd.files$path)%>%
  mutate(NLCD_Class = as.character(NLCD),
         NLCD_Class = replace_na(NLCD_Class,"Unknown"),
         NLCD_Class = ifelse(NLCD_Class %in% c("11","12","90","95"),"Water",
                             ifelse(NLCD_Class == "21", "Dev-Open",
                                    ifelse(NLCD_Class == "22","Dev-LI",
                                           ifelse(NLCD_Class == "23","Dev-MI",
                                                  ifelse(NLCD_Class == "24","Dev-HI",
                                                         ifelse(NLCD_Class == "Unknown","Unknown","Other-Rural")))))))

# Load Neighborhood
neighborhood.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/Neighborhood/outputs",full.names = TRUE),
                         file = list.files("/work/GRDVULN/sewershed/Data_Prep/Neighborhood/outputs",full.names = FALSE))%>%
  mutate(state = substr(file,9,10))%>%
  filter(state == st.fips)

neighborhood.df <- vroom(neighborhood.files$path)


# Load straight distance and calculate distance rank
e.dist.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",full.names = TRUE),
                           file = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",full.names = FALSE))%>%
  mutate(state = substr(file,6,7))%>%
  filter(state == st.fips)

d.rank <- vroom(e.dist.files$path, col_types = c("Near_CWNS"="c"))%>%
  select(!IS_EP)%>%
  group_by(h3_index)%>%
  arrange(distance)%>%
  mutate(Near_Rank = row_number())%>%
  ungroup()
colnames(d.rank)[2] <- "E_Distance"

# Route files
h3.route.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/Routing/outputs",full.names = TRUE,pattern = ".csv$"),
                          file = list.files("/work/GRDVULN/sewershed/Data_Prep/Routing/outputs",full.names = FALSE,pattern = ".csv$"))%>%
  mutate(state = substr(file,4,5))%>%
  filter(state == st.fips)

h3.route <- vroom(h3.route.files$path, col_types = c("Near_CWNS"="c"))

# Rank = 1 needs to be added for hexagons with endpoints
ep.h3 <- vroom(paste0("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs/STFP_",st.fips,".csv"),
               col_types = c("Near_CWNS"="c"))%>%
  filter(IS_EP == TRUE)%>%
  select(!IS_EP)%>%
  mutate(node = 0, Pop_B = 0, THU_B = 0,Urban_B = 0, Bldgs_B = 0)

colnames(ep.h3)[2] <- "M_Distance"

route.endpoints <- h3.route%>%
  bind_rows(ep.h3)

# Get manahatten distance
m.dist <- route.endpoints%>%
  mutate(M_Distance = ifelse(M_Distance <0,242,M_Distance))%>%
  select(!node)

# Load Residential Population Served
pop.1 <- vroom("/work/GRDVULN/sewershed/Data/POPULATION_WASTEWATER.txt")%>%
  select(CWNS_ID,TOTAL_RES_POPULATION_2022)
pop.2 <- vroom("/work/GRDVULN/sewershed/Data/POPULATION_WASTEWATER_CONFIRMED_updated06242024.csv")%>%
  select(CWNS_ID, TOTAL_RES_POPULATION_2022)

pop.all <- rbind(pop.1,pop.2)

print(paste0("Computing Closer and Farther Served @ ", round(Sys.time())))

# Calculate the sum of residential population served of closer / farther systems
# If it is the closest or farthest system, then zero
other.served <- d.rank%>%
  select(h3_index,Near_CWNS,Near_Rank)%>%
  left_join(pop.all, by = c("Near_CWNS"="CWNS_ID"))%>%
  arrange(h3_index,Near_Rank)%>%
  group_by(h3_index)%>%
  mutate(Closer_Served = cumsum(TOTAL_RES_POPULATION_2022) - TOTAL_RES_POPULATION_2022)%>%
  ungroup()%>%
  arrange(h3_index, desc(Near_Rank))%>%
  group_by(h3_index)%>%
  mutate(Farther_Served = cumsum(TOTAL_RES_POPULATION_2022) - TOTAL_RES_POPULATION_2022)%>%
  ungroup()%>%
  select(h3_index,Near_CWNS,Closer_Served,Farther_Served)

print(paste0("Finished Computing Closer and Farther Served @ ", round(Sys.time())))

# Load Place Matching
pm <- vroom(paste0("/work/GRDVULN/sewershed/Data_Prep/Place_Matching/outputs/STFP_",st.fips,".csv"),
            col_types = c("Near_CWNS"="c"))%>%
  select(h3_index,Near_CWNS,Match_Score,Match_Type)%>%
  mutate(Match_Score = ifelse(Match_Score > 1, 1,Match_Score))%>%
  group_by(h3_index,Near_CWNS)%>%
  filter(Match_Score == min(Match_Score))%>%
  filter(row_number()==1)%>%
  ungroup()%>%
  #mutate(UID = paste0(h3_index,"-",Near_CWNS))%>%
  distinct()
    
# check <- as.data.frame(table(pm$UID))%>%
#   filter(Freq > 1)

if(st.fips %in% c("02","15")){
  nlcd.df <- nlcd.df%>%
    mutate(NLCD = 50,
           Imprv_Mean = 5,
           Imprv_Med = 5,
           NLCD_Class = "Other-Rural")
  
  neighborhood.df <- neighborhood.df%>%
    mutate(NLCD_3 = 50,
           Imprv_Med_3 = 5,
           NLCD_9 = 50,
           Imprv_Med_9 = 5)
}

# TO DO
## Add in column for if the endpoint is within the same county as the hexagon.

# Load county match
# county.df <- vroom(paste0("/work/GRDVULN/sewershed/Data_Prep/H3_Counties/outputs/ST_",st.fips,".csv"))%>%
#   select(h3_index, CoFIPS)


# Combine and clean
df.all <- d.rank%>%
  left_join(pop.all, by = c("Near_CWNS"="CWNS_ID"))%>%
  left_join(m.dist)%>%
  mutate(M_Distance = replace_na(M_Distance,242),
         S_Distance = M_Distance - E_Distance)%>%
  left_join(h3.bldg)%>%
  left_join(census.weights)%>%
  mutate(Urban_Rural = replace_na(Urban_Rural,"No Population"))%>%
  left_join(nlcd.df)%>%
  left_join(neighborhood.df)%>%
  mutate(NLCD_3 = ifelse(NLCD_3 %in% c(11,12,90,95),"Water",
                         ifelse(NLCD_3 == 21, "Dev-Open",
                                ifelse(NLCD_3 == 22,"Dev-LI",
                                       ifelse(NLCD_3 == 23,"Dev-MI",
                                              ifelse(NLCD_3 == 24,"Dev-HI","Other-Rural"))))),
         NLCD_9 = ifelse(NLCD_9 %in% c(11,12,90,95),"Water",
                         ifelse(NLCD_9 == 21, "Dev-Open",
                                ifelse(NLCD_9 == 22,"Dev-LI",
                                       ifelse(NLCD_9 == 23,"Dev-MI",
                                              ifelse(NLCD_9 == 24,"Dev-HI","Other-Rural"))))),
         NLCD_Class = replace_na(NLCD_Class,"Unknown"),
         NLCD_3 = replace_na(NLCD_3,"Unknown"),
         NLCD_9 = replace_na(NLCD_9,"Unknown"))%>%
  left_join(ep.elev, by = "Near_CWNS")%>%
  left_join(elev.df, by = "h3_index")%>%
  mutate(EP_Elev_Dif = elevation_m - EP_Elevation)%>%## Calculate Elevation Change Between Hex and Endpoint
  left_join(pm, by = c("h3_index","Near_CWNS"))%>%
  left_join(other.served, by = c("h3_index","Near_CWNS"))%>%
  mutate(Match_Type = replace_na(Match_Type,"No Match"),
         NLCD = replace_na(NLCD,11),
         NLCD_3 = replace_na(NLCD_3,11),
         NLCD_9 = replace_na(NLCD_9,11))

if(!st.fips %in% c("02","15")){
  df.all <- df.all%>%
    filter(!NLCD_Class %in% c("Unknown","Water"))
}
  

df.all[is.na(df.all)] <- 0

count.na <- df.all%>%
  summarise(across(everything(), ~ sum(is.na(.))))%>%
  pivot_longer(everything(),names_to = "column", values_to = "NA_Count")%>%
  filter(NA_Count > 0)

# return rows with NA values
#filt.na <- df.all[!complete.cases(df.all),]

# Reorder columns so the most important (will always be used) will be towards the left.
df.order <- df.all%>%
  select(h3_index,Near_CWNS,TOTAL_RES_POPULATION_2022,Closer_Served,Farther_Served,Near_Rank,M_Distance,nBldgs,
         HU_90,HU_20,Pct_Sewer_90,Urban_Rural,NLCD_Class,EP_Elevation,EP_Elev_Dif,
         Imprv_Med,Match_Score,Match_Type,
         E_Distance,S_Distance,
         Pop_2020,Pop_B,THU_B,Urban_B,Bldgs_B,Med_Bldg_Height,Mean_Bldg_Height,Med_Bldg_Area,Mean_Bldg_Area,
         Imprv_Mean,
         Pop_3,THU_3,Urban_Pop_3,OHU_90_3,Pub_W_90_3,Pub_S_90_3,nBldgs_3,NLCD_3,Imprv_Med_3,
         mean_Elev_3,Pop_9,THU_9,Urban_Pop_9,OHU_90_9,Pub_W_90_9,Pub_S_90_9,nBldgs_9,NLCD_9,Imprv_Med_9,mean_Elev_9)

# Round doubles to integers
df.integer <- df.order%>%
  mutate(HU_90 = round(HU_90),
         HU_20 = round(HU_20),
         Pct_Sewer_90 = round(100*Pct_Sewer_90),
         Pop_2020 = round(Pop_2020),
         Pop_B = round(Pop_B),
         THU_B = round(THU_B),
         Urban_B = round(Urban_B),
         Bldgs_B = round(Bldgs_B),
         Med_Bldg_Height = round(Med_Bldg_Height),
         Mean_Bldg_Height = round(Mean_Bldg_Height),
         Med_Bldg_Area = round(Med_Bldg_Area),
         Mean_Bldg_Area = round(Mean_Bldg_Area),
         Imprv_Mean = round(Imprv_Mean),
         Imprv_Med = round(Imprv_Med),
         Imprv_Med_3 = round(Imprv_Med_3),
         Imprv_Med_9 = round(Imprv_Med_9),
         Pop_3 = round(Pop_3),
         THU_3 = round(THU_3),
         Urban_Pop_3 = round(Urban_Pop_3),
         OHU_90_3 = round(OHU_90_3),
         Pub_W_90_3 = round(Pub_W_90_3),
         Pub_S_90_3 = round(Pub_S_90_3),
         Pop_9 = round(Pop_9),
         THU_9 = round(THU_9),
         Urban_Pop_9 = round(Urban_Pop_9),
         OHU_90_9 = round(OHU_90_9),
         Pub_W_90_9 = round(Pub_W_90_9),
         Pub_S_90_9 = round(Pub_S_90_9))%>%
  filter(nBldgs > 0 | Pop_2020 > 0)

# Save file
vroom_write(df.integer,paste0("/work/GRDVULN/sewershed/Data_Prep/Prepare_Inputs/outputs/FP_",st.fips,".csv"),
            delim = ",", append = FALSE)

print(paste0("COMPLETED State: ",st.fips," @ ", round(Sys.time())))
