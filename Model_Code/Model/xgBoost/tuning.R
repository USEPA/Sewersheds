library(dplyr)
library(tidyr)
library(xgboost)
library(vroom)
library(stringr)
library(caret)
library(mlr)
library(parallel)
library(parallelMap) 

# https://www.hackerearth.com/practice/machine-learning/machine-learning-algorithms/beginners-tutorial-on-xgboost-parameter-tuning-r/tutorial/

print(paste0("Preparing Data @ ", round(Sys.time())))

set.seed(123)
# Load Training data
train <- vroom("/work/GRDVULN/sewershed/Model/Data/training.csv",
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
# train.sample <- sample(seq(1,nrow(train)),50000, replace = FALSE)
# train <- train[train.sample,]

# Hot encode variables for training
train.he.nlcd1 <- as.data.frame(model.matrix(object = ~ NLCD_Class - 1, data = train))%>%
  setNames(paste0(unique(train$NLCD_Class),"_1"))

train.he.nlcd3 <- as.data.frame(model.matrix(object = ~ NLCD_3 - 1, data = train))%>%
  setNames(paste0(unique(train$NLCD_3),"_3"))

train.he.nlcd9 <- as.data.frame(model.matrix(object = ~ NLCD_9 - 1, data = train))%>%
  setNames(paste0(unique(train$NLCD_9),"_9"))

train.he.mt <- as.data.frame(model.matrix(object = ~ Match_Type - 1, data = train))%>%
  setNames(unique(train$Match_Type))

m.train <- train%>%
  select(!c(h3_index,Near_CWNS,NLCD_Class,NLCD_3,NLCD_9,Match_Type,Correct_CWNS))%>%
  cbind(train.he.nlcd1, train.he.nlcd3, train.he.nlcd9, train.he.mt)%>%
  setNames(str_replace_all(colnames(.)," ","_"))%>%
  setNames(str_replace_all(colnames(.),"-","_"))%>%
  select(TOTAL_RES_POPULATION_2022,Near_Rank,E_Distance,mean_Elev_3,
         Closer_Served,Urban_Pop_9,S_Distance,Imprv_Mean,
         Match_Score,Urban_B,Pct_Sewer_90,EP_Elevation,Pop_B,
         Pub_S_90_9,No_Match,Med_Bldg_Area,Urban_Pop_3,Mean_Bldg_Area,
         EP_Elev_Dif,nBldgs,City_Place)

# Create Matrix
dtrain <- xgb.DMatrix(data = as.matrix(m.train), label = train$Correct_CWNS)


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

dtest <- xgb.DMatrix(data = as.matrix(m.test), label = test$Correct_CWNS)


print(paste0("Running Boosted Trees with Default parameters @ ", round(Sys.time())))

# Check default parameters
params <- list(booster = "gbtree", objective = "binary:logistic", eta=0.3,
               gamma=0, max_depth=6, min_child_weight=1, subsample=1,
               colsample_bytree=1)

xgbcv <- xgb.cv( params = params, data = dtrain, nrounds = 1000, nfold = 5,
                 showsd = T, stratified = T, print_every_n = 10,
                 early_stopping_rounds = 20, maximize = F)


best.iter <- which(xgbcv$evaluation_log$test_logloss_mean == min(xgbcv$evaluation_log$test_logloss_mean))
# 673

print(paste0("Completed @ ", round(Sys.time())," Minimum error:"))
min(xgbcv$evaluation_log$test_logloss_mean)

print(paste0("Best iteration: ", best.iter))


# Default first model
xgb1 <- xgb.train (params = params, data = dtrain, nrounds = best.iter,
                   watchlist = list(val=dtest,train=dtrain),
                   print_every_n = 10,
                   maximize = F , eval_metric = "error")


xgbpred <- predict (xgb1,dtest)
xgbpred <- ifelse (xgbpred > 0.5,1,0)

perf <- data.frame(truth = factor(test$Correct_CWNS, levels = c("0","1")),
                   pred = factor(xgbpred, levels = c("0","1")))

print(paste0("Confusion matrix for default parameters: ", round(Sys.time())))

print(confusionMatrix(perf$truth,perf$pred))

# Importance
#view variable importance plot
mat <- xgb.importance (feature_names = colnames(m.train),model = xgb1)
#xgb.plot.importance (importance_matrix = mat[1:20]) 

# Save Importance
write.csv(mat,"/work/GRDVULN/sewershed/Model/xgBoost/importance.csv", row.names = FALSE)

# Tuning
print(paste0("Preparing to tune @ ", round(Sys.time())))

#create tasks
train.t <- m.train%>%
  mutate(Correct_CWNS = factor(train$Correct_CWNS))

traintask <- makeClassifTask (data = train.t,target = "Correct_CWNS")

test.t <- m.test%>%
  mutate(Correct_CWNS = factor(test$Correct_CWNS))

testtask <- makeClassifTask (data = test.t,target = "Correct_CWNS")

#create learner
lrn <- makeLearner("classif.xgboost",predict.type = "response")
lrn$par.vals <- list( objective="binary:logistic", eval_metric="error", nrounds=best.iter, eta=0.1)

#set parameter space
params <- makeParamSet( makeDiscreteParam("booster",values = c("gbtree","gblinear")),
                        makeIntegerParam("max_depth",lower = 3L,upper = 10L),
                        makeNumericParam("min_child_weight",lower = 1L,upper = 10L),
                        makeNumericParam("subsample",lower = 0.5,upper = 1),
                        makeNumericParam("colsample_bytree",lower = 0.5,upper = 1))

#set resampling strategy
rdesc <- makeResampleDesc("CV",stratify = T,iters=5L)

#search strategy
ctrl <- makeTuneControlRandom(maxit = 10L)

#set parallel backend
parallelStartSocket(cpus = detectCores()-10)

print(paste0("Tuning began @ ",round(Sys.time())))

#parameter tuning
mytune <- tuneParams(learner = lrn, task = traintask, resampling = rdesc,
                     measures = acc, par.set = params, control = ctrl, show.info = T)
mytune$y 
#0.873069

print(paste0("Finished tuning parameters @ ",round(Sys.time())))

print(paste0("Findings: "))

print(mytune)


print(paste0("Evaluating against testing set ", round(Sys.time())))

params.f <- mytune$x
  # list(booster = "gbtree",
  #                objective = "binary:logistic",
  #                max_depth=8,
  #                min_child_weight=5.665721,
  #                subsample=0.8347173,
  #                colsample_bytree=0.5392676)





# Train with MLR
lrn_tune <- setHyperPars(lrn,par.vals = mytune$x)

lrn_tune <- setPredictType(lrn_tune,"prob")

xgmodel <- train(learner = lrn_tune,task = traintask)

xgpred <- predict(xgmodel,testtask)

# Save table of probabilities returned for testing data
#xgmodel <- readRDS("/work/GRDVULN/sewershed/Model/xgBoost/model.rds")


df.out <- test%>%
  mutate(Prob_CRCT = xgpred$data$prob.1)%>%
  select(h3_index,Near_CWNS,Prob_CRCT,Correct_CWNS)

vroom_write(df.out, "/work/GRDVULN/sewershed/Model/Data/Testing_Results_05052025.csv", delim = ",", append = FALSE)

confusionMatrix(xgpred$data$response,xgpred$data$truth)

print("Summary of Probabilities:")

print(summary(xgpred$data$prob.1))


print(paste0("Saving Best Model --- ",round(Sys.time())))

saveRDS(xgmodel,"/work/GRDVULN/sewershed/Model/xgBoost/model.rds")
#xgmodel <- readRDS("/work/GRDVULN/sewershed/Model/xgBoost/model.rds")


print(paste0("Computing performance "))




perf <- data.frame()

for(t in seq(0.1,0.9,0.01)){
  class <- ifelse (xgpred$data$prob.1 > t,1,0)

  compare <- data.frame(truth = factor(test$Correct_CWNS, levels = c("0","1")),
                     pred = factor(class, levels = c("0","1")))

  cm <- confusionMatrix(compare$truth,compare$pred)

  stats <- data.frame(Threshold = t,
                      Accuracy = cm$overall[[1]],
                      Kappa = cm$overall[[2]],
                      Sensitivity = cm$byClass[[1]],
                      Specificity = cm$byClass[[2]])

  perf <- rbind(perf,stats)
}


print(paste0("Performance: "))
print(perf)

print(paste0("Saving Performance --- ",round(Sys.time())))


write.csv(perf,"/work/GRDVULN/sewershed/Model/xgBoost/performance.csv", row.names = FALSE)


print(paste0("Script Complete @ ",round(Sys.time())))
