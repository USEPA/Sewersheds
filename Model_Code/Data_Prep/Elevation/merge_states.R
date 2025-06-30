library(tidyverse)
library(vroom)


# List the H3 hexagon files
h3.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",
                                         full.names = TRUE),
                       file = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",
                                         full.names = FALSE))%>%
  mutate(STFP = substr(file,6,7))


# List the elevation output files
elev.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/Elevation/outputs",
                                           full.names = TRUE),
                         file = list.files("/work/GRDVULN/sewershed/Data_Prep/Elevation/outputs",
                                           full.names = FALSE))%>%
  separate(file, into = c("A","B","STFP","File_Num"))%>%
  mutate(File_Num = str_replace(File_Num,".csv",""))

# Iterate over states and merge data, checking for completeness
completeness <- data.frame()

for(s in unique(h3.files$STFP)){
  
  # Load h3 hexagons for state
  h3.df <- vroom(h3.files$path[which(h3.files$STFP == s)], show_col_types = FALSE)%>%
    select(h3_index)%>%
    distinct()
  
  # Load elevation
  elev.df <- vroom(elev.files$path[which(elev.files$STFP==s)], show_col_types = FALSE)%>%
    filter(h3_index %in% h3.df$h3_index)%>%
    drop_na()%>%
    distinct()%>%
    group_by(h3_index)%>%
    summarise(elevation_m = mean(elevation_m))
  
  vroom_write(elev.df, paste0("/work/GRDVULN/sewershed/Data_Prep/Elevation/merged/FP_",s,".csv"),
              delim = ",", append = FALSE)
  
  newRow <- data.frame(STFP = s, nHex = nrow(h3.df), nElev = nrow(elev.df))%>%
    mutate(Pct = round(100*(nElev/nHex),3))
  
  completeness <- rbind(completeness,newRow)
  
  print(paste0(s," is ",newRow$Pct,"% Complete ... ",round(Sys.time())))
  
}
