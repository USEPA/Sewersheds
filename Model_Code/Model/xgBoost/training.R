library(dplyr)
library(tidyr)
library(xgboost)
library(vroom)
library(stringr)
library(caret)
library(mlr)

# https://www.hackerearth.com/practice/machine-learning/machine-learning-algorithms/beginners-tutorial-on-xgboost-parameter-tuning-r/tutorial/

# Load Training data
train <- vroom("/work/GRDVULN/sewershed/Model/Data/training.csv",
               col_types = c("Near_CWNS"="c","NLCD_Class"="f","NLCD_3"="f",
                             "NLCD_9"="f","Urban_Rural"="f","Correct_CWNS" = "f",
                             "Match_Type"="c"))%>%
  mutate(Correct_CWNS = ifelse(Correct_CWNS == TRUE,1,0),
         Urban = ifelse(Urban_Rural == "Urban",1,0),
         Match_Type = ifelse(Match_Type == "Match_Score","No Match",Match_Type))%>%
  select(!Urban_Rural)

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
  setNames(str_replace_all(colnames(.),"-","_"))

# Create Matrix

dtrain <- xgb.DMatrix(data = as.matrix(m.train), label = train$Correct_CWNS)


# Load Testing Data
test <- vroom("/work/GRDVULN/sewershed/Model/Data/testing.csv",
              col_types = c("Near_CWNS"="c","NLCD_Class"="f","NLCD_3"="f",
                            "NLCD_9"="f","Urban_Rural"="f","Correct_CWNS" = "f",
                            "Match_Type"="c"))%>%
  mutate(Correct_CWNS = ifelse(Correct_CWNS == TRUE,1,0),
         Urban = ifelse(Urban_Rural == "Urban",1,0),
         Match_Type = ifelse(Match_Type == "Match_Score","No Match",Match_Type))%>%
  select(!Urban_Rural)

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
  select(TOTAL_RES_POPULATION_2022,Closer_Served,Farther_Served,Near_Rank,
         M_Distance,nBldgs,HU_90,HU_20,Pct_Sewer_90,EP_Elevation,EP_Elev_Dif,
         Imprv_Med,Match_Score,E_Distance,S_Distance,Pop_2020,Pop_B,THU_B,
         Urban_B,Bldgs_B,Med_Bldg_Height,Mean_Bldg_Height,Med_Bldg_Area,
         Mean_Bldg_Area,Imprv_Mean,Pop_3,THU_3,Urban_Pop_3,OHU_90_3,Pub_W_90_3,
         Pub_S_90_3,nBldgs_3,Imprv_Med_3,mean_Elev_3,Pop_9,THU_9,Urban_Pop_9,
         OHU_90_9,Pub_W_90_9,Pub_S_90_9,nBldgs_9,Imprv_Med_9,mean_Elev_9,
         Urban,Water_1,Dev_HI_1,Dev_LI_1,Dev_MI_1,Other_Rural_1,
         Dev_Open_1,Unknown_1,Water_3,Dev_HI_3,Dev_LI_3,Dev_MI_3,Other_Rural_3,
         Dev_Open_3,Unknown_3,Water_9,Dev_HI_9,Dev_LI_9,Dev_MI_9,Other_Rural_9,
         Dev_Open_9,Unknown_9,Name_Place,City_County,City_Place,City_SubCounty,
         Name_SubCounty,No_Match,Name_County,SubCounty)

dtest <- xgb.DMatrix(data = as.matrix(m.test), label = test$Correct_CWNS)

params <- list(booster = "gbtree", objective = "binary:logistic", eta=0.3,
               gamma=0, max_depth=6, min_child_weight=1,
               subsample=1, colsample_bytree=1)

xgbcv <- xgb.cv( params = params, data = dtrain, nrounds = 200,
                 nfold = 5, showsd = T, stratified = T, print_every_n = 10,
                 early_stopping_rounds = 20, maximize = F)


min(xgbcv$evaluation_log$train_logloss_mean)


#first default - model training
xgb1 <- xgb.train (params = params, data = dtrain, nrounds = 1000,
                   watchlist = list(val=dtest,train=dtrain), print_every_n = 10,
                   early_stopping_rounds = 10, maximize = F , eval_metric = "error")
#model prediction
xgbpred <- predict (xgb1,dtest)
xgbpred <- ifelse (xgbpred > 0.5,1,0)

confusionMatrix (as.factor(xgbpred), as.factor(test$Correct_CWNS))

mat <- xgb.importance (feature_names = colnames(m.train),model = xgb1)
xgb.plot.importance (importance_matrix = mat[1:20]) 


#create tasks
train.t <- m.train%>%
  mutate(Correct_CWNS = as.factor(train$Correct_CWNS))

traintask <- makeClassifTask (data = train.t,target = "Correct_CWNS")

test.t <- m.test%>%
  mutate(Correct_CWNS = as.factor(test$Correct_CWNS))

testtask <- makeClassifTask (data = test.t,target = "Correct_CWNS")

#create learner
lrn <- makeLearner("classif.xgboost",predict.type = "response")
lrn$par.vals <- list( objective="binary:logistic", eval_metric="error", nrounds=100L, eta=0.1)

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
library(parallel)
library(parallelMap) 
parallelStartSocket(cpus = detectCores()-1)

print(paste0("Starting to tune parameters @ ",round(Sys.time())))

#parameter tuning
mytune <- tuneParams(learner = lrn, task = traintask, resampling = rdesc,
                     measures = acc, par.set = params, control = ctrl, show.info = T)
mytune$y 
#0.873069

print(paste0("Finished tuning parameters @ ",round(Sys.time())))

print(paste0("Findings: "))

print(mytune)