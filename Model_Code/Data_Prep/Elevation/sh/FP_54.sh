#!/bin/bash -l
#SBATCH --mem=100G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=largemem
#SBATCH --ntasks=128
#SBATCH --job-name=54
#SBATCH --time=1-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Elevation/messages/54.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Elevation/messages/54.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='54'
export VAR
Rscript --max-connections=256 /work/GRDVULN/sewershed/Data_Prep/Elevation/H3_Elevation.R
