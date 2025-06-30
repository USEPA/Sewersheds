#!/bin/bash -l
#SBATCH --mem=500G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=largemem
#SBATCH --job-name=29
#SBATCH --time=2-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Neighborhood/messages/29.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Neighborhood/messages/29.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='29'
export VAR
Rscript /work/GRDVULN/sewershed/Data_Prep/Neighborhood/Neighborhood.R
