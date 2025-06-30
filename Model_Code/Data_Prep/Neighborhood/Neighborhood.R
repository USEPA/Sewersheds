library(dplyr)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
library(vroom)
#library(doParallel)

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- '44'

print(paste0("Loading Data ...",round(Sys.time())))
# Load state hexagons
h3.df <- vroom(list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs", pattern = st.fips, full.names = TRUE))

# Load cross-walked 1990 Census data
census.90 <- vroom("/work/GRDVULN/sewershed/Validation/Data/Blocks_2020.csv")%>%
  select(GISJOIN,HU_1990,Public_S_90,Sewer_D_90)%>%
  filter(HU_1990 > 0)

# Load Census Data
weights <- vroom(list.files("/work/GRDVULN/sewershed/Data_Prep/03_Weight_Blocks/outputs", pattern = st.fips,
                            full.names = TRUE))%>%
  left_join(census.90)%>%
  mutate(Pop = Population*weight,
         HU = THU*weight,
         Urbn = Urban_Pop * weight,
         HU_90 = HU_1990*weight,
         Pub_W_90 = Public_S_90*weight,
         Pub_S_90 = Sewer_D_90*weight)%>%
  group_by(h3_index)%>%
  summarise(Population = sum(Pop,na.rm = TRUE),
            THU = sum(HU,na.rm = TRUE),
            Urban_Pop = sum(Urbn,na.rm = TRUE),
            OHU_90 = sum(HU_90,na.rm = TRUE),
            Pub_W_90 = sum(Pub_W_90,na.rm = TRUE),
            Pub_S_90 = sum(Pub_S_90,na.rm = TRUE))


# Load Buildings
bldg.df <- vroom(list.files("/work/GRDVULN/sewershed/Data_Prep/02_Footprints_to_Hex/outputs",
                            pattern = st.fips, full.names = TRUE))%>%
  select(h3_index,height,Area_m)%>%
  mutate(height = ifelse(height < 0,4.5,height))%>%
  group_by(h3_index)%>%
  summarise(nBldgs = n(),
            meanBldgHeight = mean(height,na.rm=TRUE),
            meanBldgArea = mean(Area_m,na.rm = TRUE))

# Load NLCD
lc.df <- vroom(list.files("/work/GRDVULN/sewershed/Data_Prep/NLCD_to_Hex/outputs", pattern = st.fips,full.names = TRUE))

# Load Elevation
elev.df <- vroom(list.files("/work/GRDVULN/sewershed/Data_Prep/Elevation/outputs", pattern = st.fips, full.names = TRUE))

# Create combined data frame
all.vars <- h3.df%>%
  select(h3_index)%>%
  distinct()%>%
  left_join(weights, by = "h3_index")%>%
  left_join(bldg.df, by = "h3_index")%>%
  left_join(lc.df, by = "h3_index")%>%
  left_join(elev.df, by = "h3_index")

# Define mode function
mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

print(paste0("Computing neighborhhod with radius: 3 ...",round(Sys.time())))

# Neighborhood of 3
# Create a data frame of h3 indices and assign a unique number to each
hex.3 <- data.frame(h3_index = unique(h3.df$h3_index))%>%
  mutate(neighborhood = 3)

# Replicate each row 7 times
hex.3.rep <- hex.3[rep(row.names(hex.3), each = 37),]

# Retrieve neighbors and assign as new column
hex.3.rep$neighbor <- unlist(lapply(hex.3$h3_index,
                                       function(x) k_ring(x, 3)))

# Join and calculate
h3.neighborhood.3 <- hex.3.rep%>%
  left_join(all.vars, by = "h3_index")%>%
  group_by(h3_index)%>%
  summarise(Pop_3 = sum(Population,na.rm = TRUE),
            THU_3 = sum(THU,na.rm = TRUE),
            Urban_Pop_3 = sum(Urban_Pop,na.rm = TRUE),
            OHU_90_3 = sum(OHU_90,na.rm = TRUE),
            Pub_W_90_3 = sum(Pub_W_90,na.rm = TRUE),
            Pub_S_90_3 = sum(Pub_S_90,na.rm = TRUE),
            nBldgs_3 = sum(nBldgs,na.rm = TRUE),
            NLCD_3 = mode(NLCD),
            Imprv_Med_3 = median(Imprv_Med,na.rm = TRUE),
            mean_Elev_3 = mean(elevation_m,na.rm = TRUE))

rm(hex.3)
rm(hex.3.rep)
gc()
print(paste0("Computing neighborhhod with radius: 9 ...",round(Sys.time())))
# Neighborhood of 9
# Create a data frame of h3 indices and assign a unique number to each
hex.9 <- data.frame(h3_index = unique(h3.df$h3_index))%>%
  mutate(neighborhood = 9)

# Replicate each row 7 times
hex.9.rep <- hex.9[rep(row.names(hex.9), each = 271),]

# Retrieve neighbors and assign as new column
hex.9.rep$neighbor <- unlist(lapply(hex.9$h3_index,
                                    function(x) k_ring(x, 9)))
# Join and calculate
h3.neighborhood.9 <- hex.9.rep%>%
  left_join(all.vars, by = "h3_index")%>%
  group_by(h3_index)%>%
  summarise(Pop_9 = sum(Population,na.rm = TRUE),
            THU_9 = sum(THU,na.rm = TRUE),
            Urban_Pop_9 = sum(Urban_Pop,na.rm = TRUE),
            OHU_90_9 = sum(OHU_90,na.rm = TRUE),
            Pub_W_90_9 = sum(Pub_W_90,na.rm = TRUE),
            Pub_S_90_9 = sum(Pub_S_90,na.rm = TRUE),
            nBldgs_9 = sum(nBldgs,na.rm = TRUE),
            NLCD_9 = mode(NLCD),
            Imprv_Med_9 = median(Imprv_Med,na.rm = TRUE),
            mean_Elev_9 = mean(elevation_m,na.rm = TRUE))%>%
  select(!h3_index)

rm(hex.9)
rm(hex.9.rep)
gc()

# print(paste0("Computing neighborhhod with radius: 16 ...",round(Sys.time())))
# 
# # Neighborhood of 16
# # Create a data frame of h3 indices and assign a unique number to each
# hex.16 <- data.frame(h3_index = unique(h3.df$h3_index))%>%
#   mutate(neighborhood = 16)
# 
# # Replicate each row 817 times
# hex.16.rep <- hex.16[rep(row.names(hex.16), each = 817),]
# 
# # Retrieve neighbors and assign as new column
# hex.16.rep$neighbor <- unlist(lapply(hex.16$h3_index,
#                                     function(x) k_ring(x, 16)))
# # Join and calculate
# h3.neighborhood.16 <- hex.16.rep%>%
#   left_join(all.vars, by = "h3_index")%>%
#   group_by(h3_index)%>%
#   summarise(Pop_16 = sum(Population,na.rm = TRUE),
#             THU_16 = sum(THU,na.rm = TRUE),
#             Urban_Pop_16 = sum(Urban_Pop,na.rm = TRUE),
#             OHU_90_16 = sum(OHU_90,na.rm = TRUE),
#             Pub_W_90_16 = sum(Pub_W_90,na.rm = TRUE),
#             Pub_S_90_16 = sum(Pub_S_90,na.rm = TRUE),
#             nBldgs_16 = sum(nBldgs,na.rm = TRUE),
#             NLCD_16 = mode(NLCD),
#             Imprv_Med_16 = median(Imprv_Med,na.rm = TRUE),
#             mean_Elev_16 = mean(elevation_m,na.rm = TRUE))%>%
#   select(!h3_index)
# 
# print(paste0("Combining and saving ...",round(Sys.time())))
# 
# rm(hex.16)
# rm(hex.16.rep)
# gc()

# Bind
all.neighborhoods <- h3.neighborhood.3%>%
  cbind(h3.neighborhood.9)

#cbind(h3.neighborhood.16)




# Save file
vroom_write(all.neighborhoods,paste0("/work/GRDVULN/sewershed/Data_Prep/Neighborhood/outputs/N_Stats_",st.fips,".csv"), delim = ",",
            append = FALSE)

print(paste0("SCRIPT COMPLETE! ...",round(Sys.time())))
