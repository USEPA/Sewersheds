# Script to generate hexagons for those that were sewered in 1990 but not assigned
library(tidyverse)
library(vroom)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")

# Load selections
selected.files <- list.files("/work/GRDVULN/sewershed/Model/Create_Boundaries/outputs/Max_Prob/text",
                             full.names = TRUE)

selected <- vroom(selected.files)



# Load sewered
prob.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/tables_clip", full.names = TRUE),
                         file = list.files("/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/tables_clip", full.names = FALSE))%>%
  mutate(state_code = str_replace(file,"BoostPredictions_",""),
         state_code = str_replace(state_code,".csv",""))

#1.07 million
sewered.90 <- data.frame()

for(n in 1:nrow(prob.files)){
  df <- vroom(prob.files$path[n])%>%
    select(h3_index,TOTAL_RES_POPULATION_2022,Pop_2020,Near_CWNS,Pct_Sewer_90,Prob_CRCT)%>%
    filter(!h3_index %in% selected$h3_index)%>%
    filter(Pct_Sewer_90 >= 90)%>%
    group_by(h3_index)%>%
    mutate(nPossible = n())%>%
    filter(Prob_CRCT == max(Prob_CRCT))%>%
    ungroup()
  
  sewered.90 <- rbind(sewered.90,df)
  
  print(paste0("Completed ",n," @ ",round(Sys.time())))
}


# Exclude Utility Boundaries
utility <- st_read("/work/GRDVULN/sewershed/Data/Utility_Polygons.shp")

sewered.m <- sewered.90%>%
  filter(!Near_CWNS %in% utility$CWNS_ID)


# Save boundaries
sewered.boundaries <- h3_to_geo_boundary_sf(sewered.m$h3_index)%>%
  left_join(sewered.m, by = "h3_index")%>%
  group_by(Near_CWNS)%>%
  summarise(Min_Prob = min(Prob_CRCT))

st_write(sewered.boundaries,"/work/GRDVULN/sewershed/Model/Create_Boundaries/outputs/Sewered_NotS_2.shp")



t <- geo_to_h3(c(47.8729890,-94.2800586), res = 9)

ring <- k_ring(t,radius = 5)

# Pull census data for ring
census <- vroom("/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/tables_clip/BoostPredictions_27.csv")%>%
  filter(h3_index %in% ring)%>%
  filter(Pct_Sewer_90 >= 90)

filt <- census%>%
  group_by(h3_index)%>%
  filter(Prob_CRCT == max(Prob_CRCT))%>%
  ungroup()


filt2 <- sewered%>%
  filter(h3_index %in% filt$h3_index)

plot(E_Distance ~ Prob_CRCT, data = census)

