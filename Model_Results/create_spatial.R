library(sf)
library(vroom)
library(tidyverse)
library(h3)


joins <- vroom("Model_Results/H3_Cnty_Join.csv")


# Load training data
train <- vroom("Model_Results/training.csv")


# Not-Sewered
train.f <- train%>%
  filter(Sewered_TRUTH == FALSE)

## Get H3 Polygons and aggregate
train.f.sf <- h3_to_geo_boundary_sf(train.f$H3_Index)%>%
  left_join(joins,by = c("h3_index"="H3_Index"))%>%
  group_by(ST_CNTY)%>%
  summarise()%>%
  mutate(Set = "Training",
         Sewered = FALSE)

# Sewered
train.t <- train%>%
  filter(Sewered_TRUTH == TRUE)

train.t.sf <- h3_to_geo_boundary_sf(train.t$H3_Index)%>%
  left_join(joins,by = c("h3_index"="H3_Index"))%>%
  group_by(ST_CNTY)%>%
  summarise()%>%
  mutate(Set = "Training",
         Sewered = TRUE)

train.sf <- rbind(train.t.sf,train.f.sf)


# Load Testing data
test <- vroom("Model_Results/predicted_top10.csv")

test.sf <- h3_to_geo_boundary_sf(test$H3_Index)

# Combine and add county / state identifiers
test.sf.out <- cbind(test.sf,test[,2:13])%>%
  left_join(joins,by = c("h3_index"="H3_Index"))

# Save data
st_write(train.sf,"Model_Results/Predicted.gpkg", layer = "training", append = FALSE)
st_write(test.sf.out,"Model_Results/Predicted.gpkg", layer = "predicted", append = FALSE)

check <- st_read("Model_Results/Predicted.gpkg", layer = "predicted")
