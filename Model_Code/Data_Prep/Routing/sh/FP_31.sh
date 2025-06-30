#!/bin/bash -l
#SBATCH --mem=200G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=31
#SBATCH --time=3-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Routing/messages/31.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Routing/messages/31.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='31'
export VAR
START_I='1'
export START_I
END_I='467'
export END_I
Rscript --max-connections=256 /work/GRDVULN/sewershed/Data_Prep/Routing/route.R
