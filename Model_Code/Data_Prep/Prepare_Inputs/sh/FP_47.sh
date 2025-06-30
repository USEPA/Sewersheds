#!/bin/bash -l
#SBATCH --mem=100G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=largemem
#SBATCH --job-name=47
#SBATCH --time=7-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/Prepare_Inputs/messages/47.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/Prepare_Inputs/messages/47.out

module load intel/24.2 R/4.4.2 gdal geos hdf5 netcdf proj udunits
VAR='47'
export VAR
Rscript /work/GRDVULN/sewershed/Data_Prep/Prepare_Inputs/Prepare_Inputs.R
