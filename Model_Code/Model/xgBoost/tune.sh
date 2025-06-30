#!/bin/bash -l
#SBATCH --mem=250GB
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=boostTune
#SBATCH --time=7-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Model/xgBoost/tuning.err
#SBATCH -o /work/GRDVULN/sewershed/Model/xgBoost/tuning.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits

Rscript /work/GRDVULN/sewershed/Model/xgBoost/tuning.R
