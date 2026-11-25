Celsius installation

cd "$HOME/bigdft-negf/pybigdfttest"
source ./2env.sh 
export BIGDFTROOT="$HOME/bigdft-negf/pybigdfttest/bigdft/build"
cd molecules/mos2_juwels/mos2_ideal
grep -n 'allocate(order(nrow))' test_negf_transport_driver.f90

mpif90 -O2 -fopenmp -fallow-argument-mismatch \
-I"$BIGDFTROOT/install/include" -I"$BIGDFTROOT/ntpoly-v3.1.1/include" \
-I"$LIBNEGF_INC" -I"$MPIFX_INC" \
test_negf_transport_driver.f90 -o test_negf_transport_driver \
-L"$BIGDFTROOT/install/lib" -L"$LIBNEGF_LIB" -L"$CONDA_PREFIX/lib" \ 
-Wl,--start-group -lorbs -latlab-1 -lCheSS-1 -lNTPoly -lfutile-1 \ 
-lyaml -lnegf -lmpifx -Wl,--end-group -llapack -lopenblas -lstdc++ -ldl -lrt


Run bias test

0.1 V --> 

python3 mos2_transport_fixed_bias.py --matrix-dir "$PWD" \
--driver "$PWD/test_negf_transport_driver" \ 
--mu-hartree 0.009194720454345 \ 
--bias-v 0.1 --mpi-ranks 2 --mpi-launcher mpirun \ 

-0.1 V -->

python3 mos2_transport_fixed_bias.py --matrix-dir "$PWD" \ 
--driver "$PWD/test_negf_transport_driver" \ 
--mu-hartree 0.009194720454345 \ 
--bias-v -0.1 --mpi-ranks 2 --mpi-launcher mpirun
