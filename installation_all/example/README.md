How to run the MoS2 test ground state analysis

Change in module.sh the path in:
source /path/to/bigdft-suite/build/install/bin/bigdftvars.sh
with your parent directory path.

Change in 48_sbatch:
source /path/to/this/installation_all/example/module.sh
source /path/to/installation_all/bigdft_env.sh
with your parent directory path.

sbatch 48_sbatch
