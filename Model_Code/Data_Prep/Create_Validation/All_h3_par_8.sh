#!/bin/bash -l
#SBATCH --mem=500G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --ntasks=128
#SBATCH --partition=largemem
#SBATCH --job-name=h3_swr_par
#SBATCH --time=4-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Create_Validation/All_h3_par_8.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Create_Validation/All_h3_par_8.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits

Rscript --max-connections=256 /work/GRDVULN/sewershed/Data_Prep/Create_Validation/Sewershed_to_H3_All_Par_8.R
