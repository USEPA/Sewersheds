# This script creates the .sh files for each state to download and save level 9 H3 Hexagons


# This script takes a very long time, and should be split up for states with > 500 endpoints
library(tidyverse)
## Import count of endpoints
ep.count <- read.csv("/work/GRDVULN/sewershed/misc/counts.csv")%>%
  mutate(nSplits = ceiling(endpoints/500),
         state = as.character(state),
         state = ifelse(nchar(state)==1,paste0("0",state),state))%>%
  select(state,endpoints,nSplits)




# Create .sh file for each state fips code

for(n in 1:nrow(ep.count)){
  
  
  if(ep.count$nSplits[n] > 1){
    
    start <- 1
    end <- 499
    split <- 1
    for(i in 1:ep.count$nSplits[n]){
      file.create(paste0("/work/GRDVULN/sewershed/Data_Prep/Routing/sh/FP_",ep.count$state[n],"_",split,".sh"))
      fileConn<-file(paste0("/work/GRDVULN/sewershed/Data_Prep/Routing/sh/FP_",ep.count$state[n],"_",split,".sh"))
      
      writeLines(c("#!/bin/bash -l",
                   "#SBATCH --mem=50G",
                   "#SBATCH --output=test_%A_%a.out",
                   "#SBATCH --error=NAMEERROR_%A_%a.out",
                   "#SBATCH --partition=largemem",
                   paste0("#SBATCH --job-name=",ep.count$state[n],"_",split),
                   "#SBATCH --time=3-00:00:00",
                   paste0("#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Routing/messages/",ep.count$state[n],"_",split,".err"),
                   paste0("#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Routing/messages/",ep.count$state[n],"_",split,".out"),
                   "",
                   "module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits",
                   
                   paste0("VAR='",ep.count$state[n],"'"),
                   "export VAR",
                   
                   paste0("START_I='",start,"'"),
                   "export START_I",
                   
                   paste0("END_I='",end,"'"),
                   "export END_I",
                   
                   "Rscript /work/GRDVULN/sewershed/Data_Prep/Routing/route.R"), fileConn)
      
      close(fileConn)
      
      start <- ceiling((start+499)/100)*100
      end <- end+500
      split <- split+1
      
    }
  } else{
    file.create(paste0("/work/GRDVULN/sewershed/Data_Prep/Routing/sh/FP_",ep.count$state[n],".sh"))
    fileConn<-file(paste0("/work/GRDVULN/sewershed/Data_Prep/Routing/sh/FP_",ep.count$state[n],".sh"))
    
    writeLines(c("#!/bin/bash -l",
                 "#SBATCH --mem=200G",
                 "#SBATCH --output=test_%A_%a.out",
                 "#SBATCH --error=NAMEERROR_%A_%a.out",
                 "#SBATCH --partition=compute",
                 paste0("#SBATCH --job-name=",ep.count$state[n]),
                 "#SBATCH --time=3-00:00:00",
                 paste0("#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Routing/messages/",ep.count$state[n],".err"),
                 paste0("#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Routing/messages/",ep.count$state[n],".out"),
                 "",
                 "module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits",
                 
                 paste0("VAR='",ep.count$state[n],"'"),
                 "export VAR",
                 
                 paste0("START_I='1'"),
                 "export START_I",
                 
                 paste0("END_I='",ep.count$endpoints[n],"'"),
                 "export END_I",
                 
                 "Rscript --max-connections=256 /work/GRDVULN/sewershed/Data_Prep/Routing/route.R"), fileConn)
    
    close(fileConn)
  }
  
}

