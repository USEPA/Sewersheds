library(dplyr)
library(vroom)
library(sf)
library(tidyr)
library(tidymodels)

print(paste0("Starting at ",round(Sys.time())))

# Systems with verified populations
pop.ver <- vroom("/work/GRDVULN/sewershed/Data/Adjusted_Training_FIX.csv")

# Load Validation Hexagons
h3.sewershed <- vroom("/work/GRDVULN/sewershed/Data_Prep/Create_Validation/Data/ALL_sewersheds_h3.csv")%>%
  filter(CWNS_ID %in% pop.ver$CWNS_ID)%>%
  mutate(UID = paste0(CWNS_ID,"-",H3_Index))%>%
  select(!H3_Index)
#colnames(h3.sewershed)[1] <- "h3_index"

# List unique CWNS IDs
cwns.valid <- unique(pop.ver$CWNS_ID)

# List states of systems
cwns.states <- unique(substr(cwns.valid,1,2))


print(paste0("Loading input variables --- ",round(Sys.time())))

# Load input variables
var.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/Prepare_Inputs/outputs",full.names = TRUE),
                        file = list.files("/work/GRDVULN/sewershed/Data_Prep/Prepare_Inputs/outputs",full.names = FALSE))%>%
  mutate(state = substr(file,4,5))%>%
  filter(state %in% cwns.states)

vars.df <- data.frame()


for(n in 1:nrow(var.files)){
  
  print(paste0("Starting state: ",var.files$state[n]," --- ",round(Sys.time())))
  st.df <- vroom(var.files$path[n], col_types = c("Near_CWNS"="c","NLCD_Class"="f","NLCD_3"="f",
                                                  "NLCD_9"="f","Urban_Rural"="f"))%>%
    #filter(Near_CWNS %in% h3.valid$Near_CWNS)%>%
    distinct()%>%
    mutate(UID = paste0(Near_CWNS,"-",h3_index))
  
  # Get hexagons for systems we have
  df.crct <- st.df%>%
    left_join(h3.sewershed, by = "UID")%>%
    filter(Near_CWNS %in% pop.ver$CWNS_ID)%>%
    mutate(Correct_CWNS = ifelse(is.na(Sewered),FALSE,
                                 ifelse(Sewered == TRUE, TRUE, NA)))%>%
    select(!c(Sewered,CWNS_ID))
  
  # Get same hexagons for other systems
  df.other <- st.df%>%
    filter(!UID %in% df.crct$UID & h3_index %in% df.crct$h3_index & !Near_CWNS %in% pop.ver$CWNS_ID)%>%
    mutate(Correct_CWNS = FALSE)
  
  
  # bind
  st.bind <- rbind(df.crct,df.other)
  
  
  vars.df <- rbind(vars.df,st.bind)
  
  print(paste0("Completed state: ",var.files$state[n]," --- ",round(Sys.time())))
}

count.na <- vars.df%>%
  summarise(across(everything(), ~ sum(is.na(.))))%>%
  pivot_longer(everything(),names_to = "column", values_to = "NA_Count")%>%
  filter(NA_Count > 0)

print(paste0("Splitting and Sampling --- ",round(Sys.time())))


# For splitting our data, we want to do it by county and we want to have representative system
# sizes in both the training and testing sets. We also have to adjust for the class imbalance
# between Correct and Incorrect System Identification. To accomplish this, we will determine the
# counties with the largest systems and split those into training and testing
# Then, we will randomly assign the other counties. We have a total of 49 counties and are
# going to use a 70/30 split between training and testing, which comes out to 34 counties for training and
# 15 counties for testing

# Counties with largest systems
# largest <- vars.df%>%
#   left_join(h3.cnty.sel, by = "h3_index")%>%
#   select(CoFIPS,TOTAL_RES_POPULATION_2022)%>%
#   distinct()%>%
#   group_by(CoFIPS)%>%
#   filter(TOTAL_RES_POPULATION_2022 == max(TOTAL_RES_POPULATION_2022))%>%
#   ungroup()%>%
#   arrange(desc(TOTAL_RES_POPULATION_2022))


# randomly sample and split so that:
## we have a 70:30 split with an equal number of TRUE and FALSE in training and testing
## Systems can only be in training or testing
print(paste0("Listing Systems... ", round(Sys.time())))
systems <- unique(vars.df$Near_CWNS)

set.seed(123)
# Training
print(paste0("Splitting Systems... ", round(Sys.time())))
train.systems <- sample(systems,round(length(systems)*0.7))
test.systems <- systems[!systems %in% train.systems]

print(paste0("Building Training... ", round(Sys.time())))

true.train <- vars.df%>%
  filter(Near_CWNS %in% train.systems & Correct_CWNS == TRUE)

s1 <- sample(seq(1,nrow(true.train)),100000)

true.train <- true.train[s1,]

false.train <- vars.df%>%
  filter(Near_CWNS %in% train.systems & Correct_CWNS == FALSE)

s2 <- sample(seq(1,nrow(false.train)),100000)

false.train <- false.train[s2,]

training <- rbind(true.train,false.train)

print(paste0("Building Testing... ", round(Sys.time())))

# Testing
true.test <- vars.df%>%
  filter(Near_CWNS %in% test.systems & Correct_CWNS == TRUE)

s3 <- sample(seq(1,nrow(true.test)),100000)

true.test <- true.test[s3,]

false.test <- vars.df%>%
  filter(Near_CWNS %in% test.systems & Correct_CWNS == FALSE)

s4 <- sample(seq(1,nrow(false.test)),100000)

false.test <- false.test[s4,]

testing <- rbind(true.test,false.test)

print(paste0("Saving... ", round(Sys.time())))

vroom_write(training,"/work/GRDVULN/sewershed/Model/Data/training.csv", delim = ",",
            append = FALSE)

vroom_write(testing,"/work/GRDVULN/sewershed/Model/Data/testing.csv", delim = ",",
            append = FALSE)

print(paste0("Training and Testing Sets Saved! --- ", round(Sys.time())))

# Create a list of Hexagons in training and testing

train.hex <- vroom("/work/GRDVULN/sewershed/Model/Data/training.csv")%>%
  select(h3_index,Near_CWNS)%>%
  mutate(Class = "Training")%>%
  distinct()

test.hex <- vroom("/work/GRDVULN/sewershed/Model/Data/testing.csv")%>%
  select(h3_index,Near_CWNS)%>%
  mutate(Class = "Testing")%>%
  distinct()


class <- rbind(train.hex,test.hex)

vroom_write(class, "/work/GRDVULN/sewershed/Model/Data/h3_splits.csv", delim = ",", append = FALSE)

# Split by system size
# system.sizes <- vars.df%>%
#   select(Near_CWNS,TOTAL_RES_POPULATION_2022)%>%
#   distinct()
# 
# set.seed(183)
# split <- initial_split(system.sizes, prop = 0.7, strata = TOTAL_RES_POPULATION_2022)
# 
# train <- training(split)
# test <- testing(split)
# 
# train.vars <- vars.df%>%
#   filter(Near_CWNS %in% train$Near_CWNS)
# 
# test.vars <- vars.df%>%
#   filter(Near_CWNS %in% test$Near_CWNS)
# 
# 
# table(train.vars$Correct_CWNS)
# table(test.vars$Correct_CWNS)
# 
# # Balance the outcomes of the training set
# train.false <- train.vars%>%
#   filter(Correct_CWNS == FALSE)
# 
# # Randomly Sample Rows to return row indices (No Duplicates)
# u.sample <- sample(seq(1,nrow(train.false)), size = 44080, replace = FALSE)
# 
# # Create replacement FALSE rows
# u.rows <- train.false[u.sample,]
# 
# # Re-Combine TRUE with under sampled FALSE
# train.u <- train.vars%>%
#   filter(Correct_CWNS == TRUE)%>%
#   rbind(u.rows)
# 
# # Balance the Testing Set
# test.false <- test.vars%>%
#   filter(Correct_CWNS == FALSE)
# 
# # Randomly Sample Rows to return row indices (No Duplicates)
# u.sample.2 <- sample(seq(1,nrow(test.false)), size = 24101, replace = FALSE)
# 
# # Create replacement FALSE rows
# u.rows.2 <- test.false[u.sample.2,]
# 
# # Re-Combine TRUE with under sampled FALSE
# test.u <- test.vars%>%
#   filter(Correct_CWNS == TRUE)%>%
#   rbind(u.rows.2)
# 
# 
# # Reorder columns and save
# # training.out <- train.u%>%
# #   select(h3_index,Near_CWNS,TOTAL_RES_POPULATION_2022,Near_Rank,distance,
# #          nBldgs,HU_90,HU_20,Pct_Sewer_90,Urban_Rural,NLCD_Class,EP_Elevation,
# #          EP_Elev_Dif,Imprv_Med,Match_Score,Match_Type,Strt_Dist,SQ_Dist,Pop_2020,Pop_B,
# #          THU_B,Urban_B,Bldgs_B,Med_Bldg_Height,Mean_Bldg_Height,Med_Bldg_Area,
# #          Mean_Bldg_Area,Imprv_Mean,Pop_3,THU_3,Urban_Pop_3,OHU_90_3,Pub_W_90_3,
# #          Pub_S_90_3,nBldgs_3,NLCD_3,Imprv_Med_3,mean_Elev_3,Pop_9,THU_9,
# #          Urban_Pop_9,OHU_90_9,Pub_W_90_9,Pub_S_90_9,nBldgs_9,NLCD_9,Imprv_Med_9,
# #          mean_Elev_9,Correct_CWNS)
# 
# vroom_write(train.u,"/work/GRDVULN/sewershed/Model/Data/training.csv", delim = ",",
#             append = FALSE)
# 
# # testing.out <- test.vars%>%
# #   select(h3_index,Near_CWNS,TOTAL_RES_POPULATION_2022,Near_Rank,distance,
# #          nBldgs,HU_90,HU_20,Pct_Sewer_90,Urban_Rural,NLCD_Class,EP_Elevation,
# #          EP_Elev_Dif,Imprv_Med,Match_Score,Match_Type,Strt_Dist,SQ_Dist,Pop_2020,Pop_B,
# #          THU_B,Urban_B,Bldgs_B,Med_Bldg_Height,Mean_Bldg_Height,Med_Bldg_Area,
# #          Mean_Bldg_Area,Imprv_Mean,Pop_3,THU_3,Urban_Pop_3,OHU_90_3,Pub_W_90_3,
# #          Pub_S_90_3,nBldgs_3,NLCD_3,Imprv_Med_3,mean_Elev_3,Pop_9,THU_9,
# #          Urban_Pop_9,OHU_90_9,Pub_W_90_9,Pub_S_90_9,nBldgs_9,NLCD_9,Imprv_Med_9,
# #          mean_Elev_9,Correct_CWNS)
# 
# vroom_write(test.vars,"/work/GRDVULN/sewershed/Model/Data/testing.csv", delim = ",",
#             append = FALSE)

print(paste0("SCRIPT COMPLETE @ ",round(Sys.time())))
