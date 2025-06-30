#!/bin/bash -l
#SBATCH --mem=200G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=12
#SBATCH --time=1-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/NLCD_to_Hex/messages/12.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/NLCD_to_Hex/messages/12.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='12'
export VAR
Rscript /work/GRDVULN/sewershed/Data_Prep/NLCD_to_Hex/NLCD_to_Hex.R
