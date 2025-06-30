#!/bin/bash -l
#SBATCH --mem=50G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=09
#SBATCH --time=1-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Model/Create_Boundaries/messages/trim/09.err
#SBATCH -o /work/GRDVULN/sewershed/Model/Create_Boundaries/messages/trim/09.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='09'
export VAR
Rscript /work/GRDVULN/sewershed/Model/Create_Boundaries/Trim_to_State.R
