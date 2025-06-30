## Data Preparation

This document outlines the necessary steps to prepare the data to be used by the random forest model. The overall desgin of these scripts is to be as compartmentalized as possible, meaning that if changes need to be made, they will effect the total workflow as little as possible. It should also be noted that while this is all R code, it is written to be run on the EPA Atmos cluster computing system, which uses slurm job scheduling. Therefore, some parts of the code may need to be altered in order to run on a different computer. 

Scripts are listed in the general order they should be run. Each script will note if it depends on another script and/or it is depended upon by another script. 

*01_Get_H3.R*
Depends on: Nothing

Depended on:

*02_Footprints_to_Hex*
Depends on: Nothing

Depended on:

*03_Weight_Blocks*
Depends on: Nothing

Depended on:

*H3_Elevation.R*
Depends on:
'01_Get_H3.R'


Depended on by:



The second set of scripts do not need to be run in order, and are effectively compartmentalized


*NLCD_to_Hex.R*
Depends on: 01_Get_H3.R


*Get_Counties.R*
Depends on:
'Weight_Blocks.R'



*Sewershed_H3*

For the validation dataset, we take every sewershed and generate a grid of points over it, we then extract the H3 hexagon Ids from those points. This tells us the CWNS_ID and whether it is sewered or not.

The last script that should be run is to combine all input data into data frames that are ready to be used in the machine learning model.

'Prepare_Inputs'

6. Landcover to Hex

7. Endpoints_to_H3
  H3 Indices are extracted for endpoints
  
8. Dist_Ring
  For every hexagon within 82 hexagons of an endpoint, the distance from every hexagon to the endpoint hexagon is calculated.
  
9. H3 Elevation
  
10. 
  
11. NLCD_to_Hex

Data Sources:

Hawaii / Alaska Imperviousness: https://coastalimagery.blob.core.windows.net/ccap-landcover/CCAP_bulk_download/High_Resolution_Land_Cover/Phase_1_Initial_Layers/Impervious/index.html

Hawaii Landcover: https://coastalimagery.blob.core.windows.net/ccap-landcover/CCAP_bulk_download/High_Resolution_Land_Cover/Phase_2_Expanded_Categories/Legacy_Land_Cover_pre_2024/Pacific/index.html


12. Neighborhood

13. OSM Extract
Extract OSM data to hexagons

13. Squirrel Distance
For each hexagon within 82 hexagons of an endpoint, we extract road data from Open street map and determine the distance (in hexagons) to reach the endpoint. We also use the nodes to extract along-route statistics such as buildings, population and housing.