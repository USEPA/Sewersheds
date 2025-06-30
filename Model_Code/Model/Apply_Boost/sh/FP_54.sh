#!/bin/bash -l
#SBATCH --mem=100G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=54
#SBATCH --time=1-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Model/Apply_Boost/messages/54.err
#SBATCH -o /work/GRDVULN/sewershed/Model/Apply_Boost/messages/54.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='54'
export VAR
Rscript /work/GRDVULN/sewershed/Model/Apply_Boost/Apply_Boost.R
