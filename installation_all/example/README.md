How to run the MoS2 test ground state analysis

Change in module.sh the path in:
source /path/to/bigdft-suite/build/install/bin/bigdftvars.sh
with your parent directory path.

Change in 48_sbatch:
source /path/to/this/installation_all/example/module.sh
source /path/to/installation_all/bigdft_env.sh
with your parent directory path.

sed -i 's/\r$//' 48_sbatch.sh

sbatch 48_sbatch
