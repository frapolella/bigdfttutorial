#============================================================
#BigDFT-libNEGF Installation Workflow
#============================================================
#
#This file describes the complete installation procedure for
#building BigDFT with libNEGF support on the JUWELS HPC system 
#via real_installer.sh.

#After cloning the repository to your HPC system, run:
  bash real_installer.sh
# The script will compile and install both software packages
# in the parent directory.
#
# The real_installer.sh and 3_test.sh workflow consists of the following main stages:
#
# 1. Load the required HPC software modules and configure the
#    environment variables for compilers, libraries, and paths.
#
# 2. Clone, configure, compile, and install libNEGF using CMake.
#
# 3. Clone the BigDFT suite repository and switch to the
#    dedicated "libnegf" branch.
#
# 4. Apply the required source-code modifications to integrate
#    libNEGF into BigDFT, including linker flags and additional
#    molybdenum (Mo) basis-set and occupation parameters.
#
# 5. Load the BigDFT environment and run the installation
#    procedure to generate the build system and compile the
#    merged BigDFT-libNEGF implementation.
#
# IMPORTANT:
# Before running the commands, verify that all directory paths,
# compiler settings, library paths, and module versions match
# the target HPC environment.
#
# Load the required HPC software modules.
source module.sh
#
# At this stage, approximately 78 modules should be loaded.
#
# This file contains the paths to the compilers and libNEGF.
# Update these paths according to the installation directories.
#
#Ex. Load the environment configuration.
source env.sh
# variables file (bigdft_env.sh) with the correct paths.
#
# You have to export the compiler variables before building
# libNEGF and then source bigdft_env.sh after installation
# to update the paths to the newly generated libraries and
# Fortran module files.


# ============================================================
# Clone and install libNEGF
# ============================================================

git clone https://github.com/libnegf/libnegf.git

cd libnegf

mkdir build

cd build

source libnegf_env.sh

cmake -S "$LIBNEGF_ROOT" -B "$LIBNEGF_BUILD" 
  -DCMAKE_INSTALL_PREFIX="$LIBNEGF_INSTALL" 
  -DBLAS_LIBRARY=openblas 
  -DBLAS_LIBRARY_DIR=/p/software/default/stages/2026/software/OpenBLAS/0.3.30-GCC-14.3.0/lib 
  -DLAPACK_LIBRARY=openblas 
  -DLAPACK_LIBRARY_DIR=/p/software/default/stages/2026/software/OpenBLAS/0.3.30-GCC-14.3.0/lib

cmake --build "$LIBNEGF_BUILD" --parallel 4

cmake --install "$LIBNEGF_BUILD"


# ============================================================
# Clone the BigDFT suite repository
# ============================================================

git clone https://gitlab.com/l_sim/bigdft-suite

cd bigdft-suite/

git checkout libnegf

cd ..

mv bigdft-suite/ src/

mkdir bigdft-suite

mv src/ bigdft-suite/.


# ============================================================
# Required modifications to the BigDFT source files
# ============================================================

# Three modifications are required before compiling BigDFT.


# 1. Update the BigDFT linker dependencies
#
# File: src/bigdft/src/Makefile.am
#
# Apply the following modification to BOTH the IF and ELSE
# branches of the bigdft_deps assignment.
#
# Add the libNEGF and mpifx library paths and linker flags.

vi bigdft/src/Makefile.am

 Required linker configuration:

 bigdft_deps += @LIB_BIGDFT_DEPS@ \
        -L/p/scratch/mat4energy/polella1/test_soft/libnegf/build/src \
        -lnegf \
        -L/p/scratch/mat4energy/polella1/test_soft/libnegf-install/lib64 \
        -lmpifx


 2. Add molybdenum (Mo) basis-set and occupation parameters

 File: src/bigdft/src/input_variables_definition.yaml

 Add the molybdenum (Mo) parameters to the corresponding
 sections of the YAML configuration file.

 A. Linear basis-set parameters:

 Locate the lin_basis_params section and find the entry
 corresponding to nickel (Ni), which should be the last entry.

 Add the following Mo entry at the end of the list:

 lin_basis_params:
   ...
   Ni: { nbasis: 10, rloc: 8.0 }
   Mo: { nbasis: 13, rloc: 7.5 }


#B. Initial-guess occupation parameters:

#Locate the ig_occupation section and find the iron (Fe)
#occupation configuration.

#Add the following Mo entry at the end of the list:

#ig_occupation:
   ...
   Fe:
     3s: 2.0
     3p: 6.0
   Mo:
     4s: 2.0
     4p: 6.0
     4d: 5.0
     5s: 1.0
     5p: 0.0


vi bigdft/src/input_variables_definition.yaml


#3. Update the projection test linker dependencies

#File: src/bigdft/tests/libs/wrappers/Makefile.am

#Modify the projection_LDADD assignment to include the
#libNEGF and mpifx library paths and linker flags.

vi bigdft/tests/libs/wrappers/Makefile.am

#Required linker configuration:

 projection_LDADD = $(bigdft_library) @LIB_FUTILE_LIBS@ @LIB_PSOLVER_LIBS@ \
        -L/p/scratch/mat4energy/polella1/test_soft/libnegf/build/src \
        -lnegf \
        -L/p/scratch/mat4energy/polella1/test_soft/libnegf-install/lib64 \
        -lmpifx


#============================================================
#Build the merged BigDFT-libNEGF implementation
#============================================================

#Load the BigDFT environment configuration.
#This step sets the compiler paths, library paths, Fortran
#module include directories, and other required build flags.

source bigdft_env.sh

cd bigdft-suite/

mkdir build

cd build/

#Generate the build system and configuration files.
python ../src/Installer.py autogen

# Compile and install the configured BigDFT-libNEGF version.
python ../src/Installer.py build -c
