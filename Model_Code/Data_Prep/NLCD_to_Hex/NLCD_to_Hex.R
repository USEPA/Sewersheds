library(stats)
library(tidyverse)
library(sf)
library(terra)
library(vroom)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")

print(paste0("Starting: ",st.fips," @ ",round(Sys.time())))

# Load Hexagons
hex.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs",
                                          full.names = TRUE),
                        file = list.files("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs"))%>%
  mutate(state_code = substr(file,6,7))%>%
  filter(state_code == st.fips)

hex.df <- vroom(hex.files$path)

h3 <- unique(hex.df$h3_index)

# Load NLCD

if(st.fips == "02"){
  nlcd <- rast("/work/GRDVULN/sewershed/Validation/Data/Alaska_2016.tif")
}

if(st.fips == "15"){
  nlcd <- rast("/work/GRDVULN/sewershed/Validation/Data/.tif")
}

if(!st.fips %in% c("02","15")){
  nlcd <- rast("/work/GRDVULN/sewershed/Validation/Data/Annual_NLCD_LndCov_2022_CU_C1V0.tif")
}


# Load Imperviousness
imprv <- rast("/work/GRDVULN/sewershed/Validation/Data/Annual_NLCD_FctImp_2022_CU_C1V0.tif")

# Define mode function
mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

# Get spatial hexagons
h3.sf <- h3_to_geo_boundary_sf(h3)%>%
  st_transform(st_crs(nlcd))


# Convert to spatVector
h3.sv <- as(h3.sf,"Spatial")%>%
  vect()

print(paste0("Extracting NLCD ",st.fips," @ ",round(Sys.time())))

# Extract NLCD
h3_nlcd <- terra::extract(nlcd,h3.sv, fun = mode)

print(paste0("Extracting Imperviousness ",st.fips," @ ",round(Sys.time())))

# Extract imperviousness
h3_imprv_mean <- terra::extract(imprv,h3.sv, fun = mean,na.rm = TRUE)
h3_imprv_med <- terra::extract(imprv,h3.sv, fun = median)

h3.sf$NLCD <- h3_nlcd$Annual_NLCD_LndCov_2022_CU_C1V0
h3.sf$Imprv_Mean <- h3_imprv_mean$Annual_NLCD_FctImp_2022_CU_C1V0
h3.sf$Imprv_Med <- h3_imprv_med$Annual_NLCD_FctImp_2022_CU_C1V0

# Save Data
h3.out <- h3.sf%>%
  st_drop_geometry()

vroom_write(h3.out, paste0("/work/GRDVULN/sewershed/Data_Prep/NLCD_to_Hex/outputs/H3_NLCD_",st.fips,".csv"),
            delim = ",", append = FALSE)

print(paste0("SCRIPT COMPLETE ",st.fips," @ ",round(Sys.time())))



