#!/bin/bash -l
#SBATCH --mem=100G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=27
#SBATCH --time=1-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/SubCounty_to_H3/messages/27.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/SubCounty_to_H3/messages/27.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='27'
export VAR
Rscript /work/GRDVULN/sewershed/Data_Prep/SubCounty_to_H3/SubCounty_to_H3.R
