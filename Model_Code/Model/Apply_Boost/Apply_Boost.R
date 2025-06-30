library(dplyr)
library(tidyr)
library(xgboost)
library(vroom)
library(stringr)
library(caret)
library(mlr)
library(sf)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- "44"

print(paste0("Starting ",st.fips," @ ",round(Sys.time())))

# Load Model
xgmodel <- readRDS("/work/GRDVULN/sewershed/Model/xgBoost/model.rds")

# Load State Data
st.df <- vroom(paste0("/work/GRDVULN/sewershed/Data_Prep/Prepare_Inputs/outputs/FP_",st.fips,".csv"),
               col_types = c("Near_CWNS"="c","NLCD_Class"="f","NLCD_3"="f",
                             "NLCD_9"="f","Urban_Rural"="f",
                             "Match_Type"="c"))%>%
  mutate(Urban = ifelse(Urban_Rural == "Urban",1,0),
         Match_Type = ifelse(Match_Type == "Match_Score","No Match",Match_Type))%>%
  select(!Urban_Rural)


# CHECK MISSING HEXAGONS
#mis <- c('894468b9607ffff','894468b963bffff','894468b9623ffff','894468b9637ffff','894468b96afffff','894468b96abffff')


print(paste0("Formatting Data ",st.fips," @ ",round(Sys.time())))

if(!st.fips %in% c("02","15")){
  # Hot encode variables
  he.nlcd1 <- as.data.frame(model.matrix(object = ~ NLCD_Class - 1, data = st.df))%>%
    setNames(paste0(unique(st.df$NLCD_Class),"_1"))
  
  he.nlcd3 <- as.data.frame(model.matrix(object = ~ NLCD_3 - 1, data = st.df))%>%
    setNames(paste0(unique(st.df$NLCD_3),"_3"))
  
  he.nlcd9 <- as.data.frame(model.matrix(object = ~ NLCD_9 - 1, data = st.df))%>%
    setNames(paste0(unique(st.df$NLCD_9),"_9"))
  
  he.mt <- as.data.frame(model.matrix(object = ~ Match_Type - 1, data = st.df))%>%
    setNames(unique(st.df$Match_Type))
  
  m.st.df <- st.df%>%
    select(!c(NLCD_Class,NLCD_3,NLCD_9,Match_Type))%>%
    cbind(he.nlcd1, he.nlcd3, he.nlcd9, he.mt)%>%
    setNames(str_replace_all(colnames(.)," ","_"))%>%
    setNames(str_replace_all(colnames(.),"-","_"))
}

if(st.fips %in% c("02","15")){
  m.st.df <- st.df%>%
    select(!c(NLCD_Class,NLCD_3,NLCD_9,Match_Type))
}

drop.ids <- m.st.df%>%
  select(!h3_index,Near_CWNS)

# Check that all needed columns are present (some states may not have certain values, and thus will be missing certain columns
# that have been hot encoded)

print(paste0("Checking for and repairing missing data ",st.fips," @ ",round(Sys.time())))

needed.cols <- c('TOTAL_RES_POPULATION_2022','Closer_Served','Farther_Served','Near_Rank',
'M_Distance','nBldgs','HU_90','HU_20','Pct_Sewer_90','EP_Elevation','EP_Elev_Dif',
'Imprv_Med','Match_Score','E_Distance','S_Distance','Pop_2020',
'Pop_B','THU_B','Urban_B','Bldgs_B',
'Med_Bldg_Height','Mean_Bldg_Height','Med_Bldg_Area',
'Mean_Bldg_Area','Imprv_Mean','Pop_3','THU_3','Urban_Pop_3','OHU_90_3',
'Pub_W_90_3','Pub_S_90_3','nBldgs_3','Imprv_Med_3','mean_Elev_3','Pop_9','THU_9','Urban_Pop_9',
'OHU_90_9','Pub_W_90_9','Pub_S_90_9','nBldgs_9','Imprv_Med_9','mean_Elev_9',
'Urban','Water_1','Dev_HI_1','Dev_LI_1','Dev_MI_1','Other_Rural_1','Dev_Open_1',
'Unknown_1','Water_3','Dev_HI_3','Dev_LI_3','Dev_MI_3','Other_Rural_3',
'Dev_Open_3','Unknown_3','Water_9','Dev_HI_9','Dev_LI_9','Dev_MI_9','Other_Rural_9',
'Dev_Open_9','Unknown_9','Name_Place','City_County','City_Place','City_SubCounty',
'Name_SubCounty','No_Match','Name_County','SubCounty')

missing.cols <- which(needed.cols%in%colnames(drop.ids)==FALSE)

if(length(missing.cols>0)){
  for(n in 1:length(missing.cols)){
    drop.ids$newColumn <- 0
    
    colnames(drop.ids)[ncol(drop.ids)] <- needed.cols[missing.cols[n]]
  }
}

df.order <- drop.ids%>%
  select(TOTAL_RES_POPULATION_2022,Near_Rank,E_Distance,mean_Elev_3,
         Closer_Served,Urban_Pop_9,S_Distance,Imprv_Mean,
         Match_Score,Urban_B,Pct_Sewer_90,EP_Elevation,Pop_B,
         Pub_S_90_9,No_Match,Med_Bldg_Area,Urban_Pop_3,Mean_Bldg_Area,
         EP_Elev_Dif,nBldgs,City_Place)

print(paste0("Running Model ",st.fips," @ ",round(Sys.time())))

# Create task
#mtask <- makeClassifTask (data = df.order,target = "Correct_CWNS")

# Apply model
xgpred <- predict(xgmodel, newdata = df.order)

print(paste0("Saving output table ",st.fips," @ ",round(Sys.time())))

# Save output table for probabilities >0.4
predicted.df <- m.st.df%>%
  mutate(Prob_CRCT = xgpred$data$prob.1)
  #filter(Prob_CRCT > 0.4)

# temp <- predicted.df%>%
#   filter(Near_CWNS == "48006105001")
# 
# temp2 <- predicted.df%>%
#   filter(h3_index == "894468b966fffff")
# 
# vroom_write(temp,"/work/GRDVULN/sewershed/temp/Texas.csv", delim = ",")
vroom_write(predicted.df,paste0("/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/tables/BoostPredictions_",st.fips,".csv"), append = FALSE)

print(paste0("Retrieving Hexagons ",st.fips," @ ",round(Sys.time())))

# Get Hexagons for predictions >= 0.6

pred.filt <- predicted.df%>%
  filter(Prob_CRCT >= 0.1)%>%
  group_by(h3_index)%>%
  filter(Prob_CRCT == max(Prob_CRCT))%>%
  ungroup()

# Get h3 indexes
h3 <- h3_to_geo_boundary_sf(pred.filt$h3_index)%>%
  cbind(pred.filt)

print(paste0("Building sewersheds ",st.fips," @ ",round(Sys.time())))
# Create Boundaries

sa <- h3%>%
  group_by(Near_CWNS)%>%
  summarise(TOTAL_RES_POPULATION_2022 = TOTAL_RES_POPULATION_2022[1],
            Pop_20 = sum(Pop_2020,na.rm = TRUE),
            HU_20 = sum(HU_20,na.rm = TRUE))%>%
  st_make_valid()

# Save boundaries
st_write(sa,"/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/Sewersheds.gpkg",layer = paste0("FP_",st.fips), append = FALSE)

print(paste0("SCRIPT COMPLETE ",st.fips," @ ",round(Sys.time())))
