#!/usr/bin/env bash

# Directory che contiene questo file
_INSTALL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Supporta sia:
# main_dir/installation_all/
# main_dir/installation_process/installation_all/
export MAIN_DIR="$(cd "$_INSTALL_DIR/.." && pwd)"
export SOFT_ROOT="$MAIN_DIR"

# libNEGF paths
export LIBNEGF_ROOT="$MAIN_DIR/libnegf"
export LIBNEGF_BUILD="$LIBNEGF_ROOT/build"
export LIBNEGF_INSTALL="$MAIN_DIR/libnegf-install"

export LIBNEGF_SRC="$LIBNEGF_ROOT/src"
export LIBNEGF_MOD1="$LIBNEGF_BUILD/src"
export LIBNEGF_MOD2="$LIBNEGF_BUILD/src/include"

export LIBNEGF_INC="$LIBNEGF_INSTALL/include/modfiles"
export MPIFX_INC="$LIBNEGF_INSTALL/include/mpifx/modfiles"
export NEGF_MPIFX_LIB="$LIBNEGF_INSTALL/lib64"

# OpenBLAS on JUWELS
export OPENBLAS_ROOT="/p/software/default/stages/2026/software/OpenBLAS/0.3.30-GCC-14.3.0"
export OPENBLAS_LIB="$OPENBLAS_ROOT/lib"

# MPI compilers
export CC=mpicc
export CXX=mpicxx
export FC=mpifort

# Avoid carrying BigDFT/linking flags into the initial libNEGF build.
unset CPPFLAGS CFLAGS CXXFLAGS FCFLAGS FFLAGS LDFLAGS

echo "Ambiente libNEGF:"
echo "  MAIN_DIR       = $MAIN_DIR"
echo "  LIBNEGF_ROOT   = $LIBNEGF_ROOT"
echo "  LIBNEGF_BUILD  = $LIBNEGF_BUILD"
echo "  LIBNEGF_INSTALL= $LIBNEGF_INSTALL"
echo "  OPENBLAS_LIB   = $OPENBLAS_LIB"
