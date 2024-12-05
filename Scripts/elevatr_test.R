library(sf)
library(elevatr)
library(terra)
library(dplyr)
library(tidyr)

sv <- st_read("D:/temp/sample_blks.shp")

dem <- get_elev_raster(sv, z = 12)

sv <- vect(sv)

r <- rast(dem)

vals <- terra::extract(r,sv, fun=table)

vals$GISJOIN <- sv$GISJOIN

stats <- vals%>%
  select(!ID)%>%
  pivot_longer(!GISJOIN, names_to = "Elevation", values_to = "Count")%>%
  filter(Count > 0)

wm <- stats%>%
  mutate(Elevation = as.numeric(Elevation))%>%
  group_by(GISJOIN)%>%
  mutate(Mean = weighted.mean(Elevation, Count, na.rm = TRUE),
         Min = min(Elevation, na.rm=TRUE),
         Max = max(Elevation, na.rm = TRUE))%>%
  ungroup()%>%
  select(GISJOIN,Min,Mean,Max)%>%
  distinct()

test <- wm%>%
  filter(GISJOIN == "G44000300207011000")

library(ggplot2)

ggplot(test)+
  geom_col(aes(x = Elevation, y = Count))+
  geom_segment(x = 167.2227, xend = 167.2227, y = 0, yend=400, color = "red")
