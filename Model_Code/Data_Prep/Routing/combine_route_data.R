library(tidyverse)
library(vroom)

# Load count of endpoints by state
ep.count <- read.csv("/work/GRDVULN/sewershed/misc/counts.csv")%>%
  mutate(state = as.character(state),
         state = ifelse(nchar(state)==1,paste0("0",state),state))

states <- list.dirs("/work/GRDVULN/sewershed/Data_Prep/Routing/outputs", full.names = FALSE)
states <- states[grepl("FP_",states)]
states <- str_replace(states,"FP_","")


dirs <- list.dirs("/work/GRDVULN/sewershed/Data_Prep/Routing/outputs", full.names = TRUE)
dirs <- dirs[grepl("FP_",dirs)]


# Check for completeness
file.count <- data.frame()

for(n in 1:length(dirs)){
  unique(files <- list.files(dirs[n]))
  
  newRow <- data.frame(state = states[n], route_files = length(files))
  
  file.count <- rbind(file.count,newRow)
}

cmplt.check <- ep.count%>%
  left_join(file.count)%>%
  mutate(Pct_Complete = round(100*(route_files/endpoints),2))


for(n in 1:length(states)){
  
  files <- list.files(paste0(dirs[n]), full.names = TRUE)
  
  df <- vroom(files)
  
  vroom_write(df,paste0("/work/GRDVULN/sewershed/Data_Prep/Routing/outputs/FP_",states[n],".csv"),
              delim = ",", append = FALSE)
  
}


