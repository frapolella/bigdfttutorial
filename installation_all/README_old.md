#I diversi passaggi che fa l'algoritmo sono indicate da un #

source module_list.sh
  --> dovresti avere ora 78 moduli attivi
  --> dopo la compilazione aprire il file e modifica il path di bigdfvars.sh

source env.sh
  --> contine path per i compilatori e libnegf da modificare
  --> potresti dover prima esportare i compilatori e dopo l'installazione di negf ri-usare il comando per ricollegare i path aggiornati


#Clona e installa libnegf

git clone https://github.com/libnegf/libnegf.git

cd libnegf

mkdir build

cd build

source libnegf_env.sh

cmake -S "$LIBNEGF_ROOT" -B "$LIBNEGF_BUILD" \
  -DCMAKE_INSTALL_PREFIX="$LIBNEGF_INSTALL" \
  -DBLAS_LIBRARY=openblas \
  -DBLAS_LIBRARY_DIR=/p/software/default/stages/2026/software/OpenBLAS/0.3.30-GCC-14.3.0/lib \
  -DLAPACK_LIBRARY=openblas \
  -DLAPACK_LIBRARY_DIR=/p/software/default/stages/2026/software/OpenBLAS/0.3.30-GCC-14.3.0/lib

cmake --build "$LIBNEGF_BUILD" --parallel 4

cmake --install "$LIBNEGF_BUILD"


#Clona bigdft-suite

git clone https://gitlab.com/l_sim/bigdft-suite

cd bigdft-suite/

git checkout libnegf

cd ..

mv bigdft-suite/ src/

mkdir bigdft-suite

mv src/ bigdft-suite/.

#Tre modifiche da fare

cd src/bigdft/

1) vi bigdft/src/Makefile.am

CAMBIA SIA PER if che per ELSE
       bigdft_deps += @LIB_BIGDFT_DEPS@ \
       -L/p/scratch/mat4energy/polella1/test_soft/libnegf/build/src \
       -lnegf \
       -L/p/scratch/mat4energy/polella1/test_soft/libnegf-install/lib64 \
       -lmpifx

2) vi /bigdft/src/input_variable_definition.yaml

AGGIUNGI VARIABILI Mo

CERCA CHE CONCLUDA CON Ni -->
         lin_basis_params:
         ...
         Ni: { nbasis: 10, rloc: 8.0 }

AGGIUNGE A FINE LISTA -->
         lin_basis_params:
         ...
         Ni: { nbasis: 10, rloc: 8.0 }
         Mo: { nbasis: 13, rloc: 7.5 }

CERCA --> 
        ig_occupation:
            Fe:
              3s: 2.0
              3p: 6.0
AGGIUNGE A FINE LISTA -->
           ig_occupation:
                  ... 
                  Mo:
                    4s: 2.0
                    4p: 6.0
                    4d: 5.0
                    5s: 1.0
                    5p: 0.0

3) vi /bigdft/tests/libs/wrappers/Makefile.am

CAMBIA projection_LDADD = $(bigdft_library) @LIB_FUTILE_LIBS@ @LIB_PSOLVER_LIBS@ \
       -L/p/scratch/mat4energy/polella1/test_soft/libnegf/build/src \
       -lnegf \
       -L/p/scratch/mat4energy/polella1/test_soft/libnegf-install/lib64 \
       -lmpifx

#Installazione BigDFT-LibNEGF merged

source bigdft_env.sh

cd bigdft-suite/

mkdir build

cd build/

python ../src/Installer.py autogen

python ../src/Installer.py build -c