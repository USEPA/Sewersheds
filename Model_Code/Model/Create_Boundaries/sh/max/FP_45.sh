#!/bin/bash -l
#SBATCH --mem=50G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=45
#SBATCH --time=1-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Model/Create_Boundaries/messages/max/45.err
#SBATCH -o /work/GRDVULN/sewershed/Model/Create_Boundaries/messages/max/45.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='45'
export VAR
Rscript /work/GRDVULN/sewershed/Model/Create_Boundaries/Max_Boundaries.R
