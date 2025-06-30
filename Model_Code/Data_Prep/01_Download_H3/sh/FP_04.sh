#!/bin/bash -l
#SBATCH --mem=50G
#SBATCH --output=test_%A_%a.out
#SBATCH --error=NAMEERROR_%A_%a.out
#SBATCH --partition=compute
#SBATCH --job-name=04
#SBATCH --time=7-00:00:00
#SBATCH -e /work/GRDVULN/sewershed/Data_Prep/01_Download_H3/messages/04.err
#SBATCH -o /work/GRDVULN/sewershed/Data_Prep/01_Download_H3/messages/04.out

module load intel/21.4 R/4.3.0 gdal geos hdf5 netcdf proj udunits
VAR='04'
export VAR
Rscript /work/GRDVULN/sewershed/Data_Prep/01_Download_H3/01_Get_H3.R
