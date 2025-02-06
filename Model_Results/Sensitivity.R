library(vroom)
library(tidymodels)
library(dplyr)
library(plotly)

# Load predictions
pred.df <- vroom("Model_Results/predicted_top10.csv")


sensitivity.df <- data.frame()

pb <- txtProgressBar(min = 0, max = 10, style = 3)
for(c in 4:13){
  
  subset <- pred.df%>%
    select(Sewered_TRUTH,all_of(c))%>%
    setNames(c("truth","prob"))
  
  for(n in seq(0.05,0.95,0.01)){
    class.df <- subset%>%
      mutate(class = ifelse(prob >= n,TRUE,FALSE),
             truth = factor(truth),
             class = factor(class))
    
    mets <- metrics(class.df,truth,class)
    
    # Write Accuracy
    acc <- as.numeric(mets[1,3])
    
    # Write Kappa
    kappa <- as.numeric(mets[2,3])
    
    cm <- conf_mat(class.df,truth,class)
    
    # True positives
    # Write Sensitivity
    sensitivity <- cm$table[2,2]/(cm$table[2,2]+ cm$table[1,2])
    
    # True Negatives
    # Write specificity
    specificity <- cm$table[1,1]/(cm$table[2,1]+ cm$table[1,1])
    
    newRow <- data.frame(Model = colnames(pred.df)[c],
                         Threshold = n,
                         Accuracy = acc,
                         Kappa = kappa,
                         Sensitivity = sensitivity,
                         Specificity = specificity)
    
    sensitivity.df <- rbind(sensitivity.df,newRow)
    
  }
  
  setTxtProgressBar(pb,c)
  
}


ggplot(sensitivity.df)+
  geom_line(aes(x = Threshold, y = Sensitivity, color = Model, group = Model))+
  geom_line(aes(x = Threshold, y = Specificity, color = Model, group = Model))+
  geom_line(aes(x = Threshold, y = Accuracy, color = Model, group = Model),linetype = "dashed")


vroom_write(sensitivity.df,"Model_Results/sensitivity_sewered.csv", delim = ",", append = FALSE)

plot_ly(sensitivity.df)%>% 
  add_lines(x = ~Threshold, y = ~Sensitivity, color = ~Model, group = ~Model,
            text = ~paste0("<b>Sensitivity (True Sewered)</b><br>",
                           "Model: ",Model,"<br>",
                           "Accuracy: ",round(100*Accuracy,2),"<br>",
                           "Sensitivity: ",round(100*Sensitivity,2),"<br>",
                           "Specificity: ",round(100*Specificity,2)),
            hoverinfo = 'text')%>%
  add_lines(x = ~Threshold, y = ~Specificity, color = ~Model, group = ~Model,
            text = ~paste0("<b>Specificity (True Non-Sewered)</b><br>",
                           "Model: ",Model,"<br>",
                           "Accuracy: ",round(100*Accuracy,2),"<br>",
                           "Sensitivity: ",round(100*Sensitivity,2),"<br>",
                           "Specificity: ",round(100*Specificity,2)),
            hoverinfo = 'text')%>%
  add_lines(x = ~Threshold, y = ~Accuracy, color = ~Model, group = ~Model, linetype = ~Model,
            text = ~paste0("<b>Total Model Accuracy</b><br>",
                           "Model: ",Model,"<br>",
                           "Accuracy: ",round(100*Accuracy,2),"<br>",
                           "Sensitivity: ",round(100*Sensitivity,2),"<br>",
                           "Specificity: ",round(100*Specificity,2)),
            hoverinfo = 'text')%>%
  layout(title = "Model Sensitivity and Specificity",
         xaxis = list(title = "Probability Threshold"),
         yaxis = list(title = "Accuracy / Sensitivity / Specificity"),
         showlegend = FALSE)


# Calculate AUC for each model

auc.df <- data.frame()

for(c in 4:13){
  
  subset <- pred.df%>%
    select(Sewered_TRUTH,all_of(c))%>%
    setNames(c("truth","prob"))%>%
    mutate(truth = factor(truth, levels = c(TRUE,FALSE)))
  
  auc <- roc_auc(subset,truth,prob)
  
  newRow <- data.frame(Model = colnames(pred.df)[c],
                       AUC = as.numeric(auc[1,3]))
  
  auc.df <- rbind(auc.df,newRow)
  
}

roc <- roc_curve(subset,truth,prob)
  plot_ly(roc)%>%
  add_lines(x = ~1-specificity, y = ~sensitivity)%>%
  layout(title = "ROC Curve",
         xaxis = list(title = "False Positive Rate"),
         yaxis = list(title = "True Positive Rate"))

  ggplot(roc,aes(x = 1 - specificity, y = sensitivity)) +
    geom_path() +
    geom_abline(lty = 3) +
    coord_equal() +
    theme_bw()
  