#!/bin/bash -l
#SBATCH --mem=200G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=29
#SBATCH --time=1-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/OSM_to_Hex/messages/29.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/OSM_to_Hex/messages/29.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='29'
export VAR
Rscript /work/GRDVULN/sewershed/Data_Prep/OSM_to_Hex/OSM_to_Hex.R
