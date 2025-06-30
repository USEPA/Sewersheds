library(dplyr)
library(vroom)

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")

files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/03_Weight_Blocks/outputs",
                                      full.names = TRUE),
                    file = list.files("/work/GRDVULN/sewershed/Data_Prep/03_Weight_Blocks/outputs",
                                             full.names = FALSE))%>%
  mutate(State = substr(file,13,14))




for(n in 1:nrow(files)){
  # Load Census Weights
  df <- vroom(files$path[n])
  
  # County
  counties <- df%>%
    select(h3_index,GISJOIN)%>%
    mutate(StFIPS = substr(GISJOIN,2,3),
           CoFIPS = paste0(StFIPS,substr(GISJOIN,5,7)))%>%
    select(h3_index,StFIPS,CoFIPS)
  
  vroom_write(counties,paste0("/work/GRDVULN/sewershed/Data_Prep/H3_Counties/outputs/ST_",files$State[n],".csv"),
              delim = ",", append = FALSE)
}
