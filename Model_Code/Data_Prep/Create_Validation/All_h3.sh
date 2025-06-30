#!/bin/bash -l
#SBATCH --mem=100G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=h3_swr
#SBATCH --time=4-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Create_Validation/All_h3_sewershed.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Create_Validation/All_h3_sewershed.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits

Rscript /work/GRDVULN/sewershed/Data_Prep/Create_Validation/Sewershed_to_H3_All.R
