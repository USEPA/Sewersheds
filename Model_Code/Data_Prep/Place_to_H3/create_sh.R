# This script creates the .sh files for each state to download and save level 9 H3 Hexagons


library(tidyverse)
library(sf)

# Load county layer
counties <- st_read("/work/GRDVULN/sewershed/Data/US_county_2022.shp")%>%
  st_drop_geometry()

# Pull state fips codes from layer
st.fips <- unique(counties$STATEFP)

# Create .sh file for each state fips code

for(n in 1:length(st.fips)){
  file.create(paste0("/work/GRDVULN/sewershed/Data_Prep/Place_to_H3/sh/FP_",st.fips[n],".sh"))
  fileConn<-file(paste0("/work/GRDVULN/sewershed/Data_Prep/Place_to_H3/sh/FP_",st.fips[n],".sh"))
  
  writeLines(c("#!/bin/bash -l",
               "#SBATCH --mem=50G",
               "#SBATCH --output=test_%A_%a.out",
               "#SBATCH --error=NAMEERROR_%A_%a.out",
               "#SBATCH --partition=compute",
               paste0("#SBATCH --job-name=",st.fips[n]),
               "#SBATCH --time=1-00:00:00",
               paste0("#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Place_to_H3/messages/",st.fips[n],".err"),
               paste0("#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Place_to_H3/messages/",st.fips[n],".out"),
               "",
               "module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits",
               
               paste0("VAR='",st.fips[n],"'"),
               "export VAR",
               "Rscript /work/GRDVULN/sewershed/Data_Prep/Place_to_H3/Place_to_H3.R"), fileConn)
  
  close(fileConn)
}

