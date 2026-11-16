#!/bin/bash
#SBATCH --account=mat4energy
#SBATCH --partition=batch
#SBATCH --nodes=4
#SBATCH --ntasks=48
#SBATCH --cpus-per-task=2
#SBATCH --time=10:30:00
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

source /p/home/jusers/polella1/juwels/newbigdft/new_module.sh
source /p/home/jusers/polella1/juwels/newbigdft/new_env.sh

export BIGDFT_MPIRUN="srun"
python mos2_no_defects.py