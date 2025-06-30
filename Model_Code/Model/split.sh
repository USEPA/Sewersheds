#!/bin/bash -l
#SBATCH --mem=500G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=largemem
#SBATCH --job-name=Split
#SBATCH --time=1-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Model/split.err
#SBATCH -o /work/GRDVULN/sewershed/Model/split.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits

Rscript /work/GRDVULN/sewershed/Model/Split_Data.R
