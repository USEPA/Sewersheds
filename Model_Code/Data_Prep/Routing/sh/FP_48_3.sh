#!/bin/bash -l
#SBATCH --mem=50G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=largemem
#SBATCH --job-name=48_3
#SBATCH --time=3-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Routing/messages/48_3.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Routing/messages/48_3.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='48'
export VAR
START_I='1000'
export START_I
END_I='1499'
export END_I
Rscript /work/GRDVULN/sewershed/Data_Prep/Routing/route.R
