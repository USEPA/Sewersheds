library(dplyr)
library(tidyr)
library(xgboost)
library(vroom)
library(stringr)
library(caret)
library(mlr)
library(parallel)
library(parallelMap)


# Load Testing Data
test <- vroom("/work/GRDVULN/sewershed/Model/Data/testing.csv",
              col_types = c("Near_CWNS"="c","NLCD_Class"="f","NLCD_3"="f",
                            "NLCD_9"="f","Urban_Rural"="f","Correct_CWNS" = "f",
                            "Match_Type"="c",
                            'TOTAL_RES_POPULATION_2022'='i','Closer_Served'='i','Farther_Served'='i',
                            'Near_Rank'='i','M_Distance'='i','nBldgs'='i','HU_90'='i',
                            'HU_20'='i','Pct_Sewer_90'='i','EP_Elevation'='i',
                            'EP_Elev_Dif'='i','Imprv_Med'='i','Match_Score'='i',
                            'E_Distance'='i','S_Distance'='i',
                            'Pop_2020'='i','Pop_B'='i','THU_B'='i','Urban_B'='i',
                            'Bldgs_B'='i','Med_Bldg_Height'='i',
                            'Mean_Bldg_Height'='i','Med_Bldg_Area'='i',
                            'Mean_Bldg_Area'='i','Imprv_Mean'='i','Pop_3'='i',
                            'THU_3'='i','Urban_Pop_3'='i','OHU_90_3'='i',
                            'Pub_W_90_3'='i','Pub_S_90_3'='i','nBldgs_3'='i',
                            'Imprv_Med_3'='i','mean_Elev_3'='i','Pop_9'='i',
                            'THU_9'='i','Urban_Pop_9'='i','OHU_90_9'='i',
                            'Pub_W_90_9'='i','Pub_S_90_9'='i','nBldgs_9'='i',
                            'Imprv_Med_9'='i','mean_Elev_9'='i'))%>%
  mutate(Correct_CWNS = ifelse(Correct_CWNS == FALSE,0,1),
         Urban = ifelse(Urban_Rural == "Urban",1,0),
         Match_Type = ifelse(Match_Type == "Match_Score","No Match",Match_Type))%>%
  select(!Urban_Rural)

# FOR TESTING
# test.sample <- sample(seq(1,nrow(test)),50000, replace = FALSE)
# test <- test[test.sample,]

# Hot encode variables for testing
test.he.nlcd1 <- as.data.frame(model.matrix(object = ~ NLCD_Class - 1, data = test))%>%
  setNames(paste0(unique(test$NLCD_Class),"_1"))

test.he.nlcd3 <- as.data.frame(model.matrix(object = ~ NLCD_3 - 1, data = test))%>%
  setNames(paste0(unique(test$NLCD_3),"_3"))

test.he.nlcd9 <- as.data.frame(model.matrix(object = ~ NLCD_9 - 1, data = test))%>%
  setNames(paste0(unique(test$NLCD_9),"_9"))

test.he.mt <- as.data.frame(model.matrix(object = ~ Match_Type - 1, data = test))%>%
  setNames(unique(test$Match_Type))

m.test <- test%>%
  select(!c(h3_index,Near_CWNS,NLCD_Class,NLCD_3,NLCD_9,Match_Type,Correct_CWNS))%>%
  cbind(test.he.nlcd1, test.he.nlcd3, test.he.nlcd9, test.he.mt)%>%
  setNames(str_replace_all(colnames(.)," ","_"))%>%
  setNames(str_replace_all(colnames(.),"-","_"))%>%
  select(TOTAL_RES_POPULATION_2022,Near_Rank,E_Distance,mean_Elev_3,
         Closer_Served,Urban_Pop_9,S_Distance,Imprv_Mean,
         Match_Score,Urban_B,Pct_Sewer_90,EP_Elevation,Pop_B,
         Pub_S_90_9,No_Match,Med_Bldg_Area,Urban_Pop_3,Mean_Bldg_Area,
         EP_Elev_Dif,nBldgs,City_Place)


test.t <- m.test%>%
  mutate(Correct_CWNS = factor(test$Correct_CWNS))


# Load model
xgmodel <- readRDS("/work/GRDVULN/sewershed/Model/xgBoost/model.rds")

# Create task
testtask <- makeClassifTask (data = test.t,target = "Correct_CWNS")

# Predict
xgpred <- predict(xgmodel,testtask)


# Get optimal cutoff and calculate accuracy for entire model
perf.all <- data.frame()

for(t in seq(0.01,0.99,0.01)){
  class <- ifelse (xgpred$data$prob.1 > t,1,0)
  
  compare <- data.frame(truth = factor(test$Correct_CWNS, levels = c("0","1")),
                        pred = factor(class, levels = c("0","1")))
  
  cm <- confusionMatrix(compare$truth,compare$pred)
  
  stats <- data.frame(Threshold = t,
                      Accuracy = cm$overall[[1]],
                      Kappa = cm$overall[[2]],
                      Specificity = cm$byClass[[1]],
                      Sensitivity = cm$byClass[[2]])%>%
    mutate(dif = abs(Sensitivity - Specificity))
  
  
  
  perf.all <- rbind(perf.all,stats)
  
  print(t)
}


# Check systems under 10,000
small.class <- class.df%>%
  filter(TOTAL_RES_POPULATION_2022 <= 10000)

class <- ifelse (subset$Prob > t,1,0)

compare <- data.frame(truth = factor(subset$Correct_CWNS, levels = c("0","1")),
                      pred = factor(class, levels = c("0","1")))

cm <- confusionMatrix(compare$truth,compare$pred)




bins <- test%>%
  mutate(Prob = xgpred$data$prob.1,
         bin = cut(TOTAL_RES_POPULATION_2022, breaks = c(0,1000,5000,10000,100000,Inf),
                   labels = c("0 - 1,000","1,001 - 5,000","5,001 - 10,000","10,001 - 100,000","> 100,000")))%>%
  select(h3_index,Near_CWNS,TOTAL_RES_POPULATION_2022,Prob,bin,Correct_CWNS)


# Evaluate accuracy of the bins using the 0.18 cutoff
bins.18 <- data.frame()
for(b in unique(bins$bin)){
  subset <- bins%>%
    filter(bin == b)
  
    class <- ifelse (subset$Prob > 0.18,1,0)
    
    compare <- data.frame(truth = factor(subset$Correct_CWNS, levels = c("0","1")),
                          pred = factor(class, levels = c("0","1")))
    
    cm <- confusionMatrix(compare$truth,compare$pred)
    
    stats <- data.frame(Bin = b,
                        Threshold = 0.18,
                        Accuracy = cm$overall[[1]],
                        Kappa = cm$overall[[2]],
                        Specificity = cm$byClass[[1]],
                        Sensitivity = cm$byClass[[2]])%>%
      mutate(dif = abs(Sensitivity - Specificity))
    
    
    
    bins.18 <- rbind(bins.18,stats)
  }
  
write.csv(bins.18,"/work/GRDVULN/sewershed/Validation/Data/H3_9_Bin_18_Accuracy.csv")


# Iterate through bins to calculate accuracy sensitivity, specificity
bin.stats <- data.frame()

for(b in unique(bins$bin)){
  subset <- bins%>%
    filter(bin == b)
  
  # Find optimum cutoff
  perf <- data.frame()
  
  for(t in seq(0.01,0.99,0.01)){
    class <- ifelse (subset$Prob > t,1,0)
    
    compare <- data.frame(truth = factor(subset$Correct_CWNS, levels = c("0","1")),
                          pred = factor(class, levels = c("0","1")))
    
    cm <- confusionMatrix(compare$truth,compare$pred)
    
    stats <- data.frame(Threshold = t,
                        Accuracy = cm$overall[[1]],
                        Kappa = cm$overall[[2]],
                        Specificity = cm$byClass[[1]],
                        Sensitivity = cm$byClass[[2]])%>%
      mutate(dif = abs(Sensitivity - Specificity))
    
    
    
    perf <- rbind(perf,stats)
    
    print(t)
  }
  
  row.sel <- which(perf$dif == min(perf$dif))
  
  newRow <- perf[row.sel,]
  newRow$bin <-  b
  
  bin.stats <- rbind(bin.stats,newRow)
}


bin.counts <- bins%>%
  group_by(bin)%>%
  summarise(hex_count = n())

bins.out <- bin.stats%>%
  left_join(bin.counts)

write.csv(bins.out,"/work/GRDVULN/sewershed/Validation/Data/H3_9_Bin_Accuracy.csv")


# Test pop-based probability threshold
class.df <- test%>%
  select(TOTAL_RES_POPULATION_2022,Correct_CWNS)%>%
  mutate(prob = xgpred$data$prob.1,
         pred = ifelse(TOTAL_RES_POPULATION_2022 <= 1000 & prob > 0.77,1,
                       ifelse(TOTAL_RES_POPULATION_2022 <= 5000 & prob > 0.62,1,
                              ifelse(TOTAL_RES_POPULATION_2022 <= 10000 & prob >0.42,1,
                                     ifelse(TOTAL_RES_POPULATION_2022 <= 100000 & prob > 0.15,1,
                                            ifelse(TOTAL_RES_POPULATION_2022 >100000 & prob > 0.01,1,0))))))



compare <- data.frame(truth = factor(class.df$Correct_CWNS, levels = c("0","1")),
                      pred = factor(class.df$pred, levels = c("0","1")))

cm <- confusionMatrix(compare$truth,compare$pred)

cm

# Check systems under 10,000
small.class <- class.df%>%
  filter(TOTAL_RES_POPULATION_2022 <= 10000)

compare.small <- data.frame(truth = factor(small.class$Correct_CWNS, levels = c("0","1")),
                      pred = factor(small.class$pred, levels = c("0","1")))

confusionMatrix(compare.small$truth,compare.small$pred)





