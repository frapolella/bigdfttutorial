#!/usr/bin/env bash

# ============================================================
# Determine MAIN_DIR from this file's location
# installation_process/installation_all/bigdft_env.sh
# ============================================================

_BDFT_ENV_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export MAIN_DIR="$(cd "$_BDFT_ENV_DIR/.." && pwd)"
export SOFT_ROOT="$MAIN_DIR"

# ============================================================
# MPI compilers
# ============================================================

export CC="$(command -v mpicc)"
export CXX="$(command -v mpicxx)"
export FC="$(command -v mpifort)"
export F77="$FC"
export F90="$FC"
export MPICC="$CC"
export MPIFC="$FC"

# ============================================================
# BigDFT
# ============================================================

export BIGDFT_ROOT="$MAIN_DIR/bigdft-suite"
export BIGDFT_SRC="$BIGDFT_ROOT/src"
export BIGDFT_BUILD="$BIGDFT_ROOT/build"
export BIGDFT_INSTALL="$BIGDFT_BUILD/install"

# ============================================================
# libNEGF
# ============================================================

export LIBNEGF_ROOT="$MAIN_DIR/libnegf"
export LIBNEGF_BUILD="$LIBNEGF_ROOT/build"
export LIBNEGF_INSTALL="$MAIN_DIR/libnegf-install"

export LIBNEGF_MOD1="$LIBNEGF_BUILD/src"
export LIBNEGF_MOD2="$LIBNEGF_BUILD/src/include"

export LIBNEGF_INC="$LIBNEGF_INSTALL/include/modfiles"
export MPIFX_INC="$LIBNEGF_INSTALL/include/mpifx/modfiles"
export NEGF_MPIFX_LIB="$LIBNEGF_INSTALL/lib64"

# ============================================================
# OpenBLAS
# ============================================================

export OPENBLAS_ROOT="/p/software/default/stages/2026/software/OpenBLAS/0.3.30-GCC-14.3.0"
export OPENBLAS_LIB="$OPENBLAS_ROOT/lib"

# ============================================================
# Compiler flags
# ============================================================

export CPPFLAGS="-I$LIBNEGF_INC -I$LIBNEGF_MOD1 -I$LIBNEGF_MOD2 -I$MPIFX_INC"

export CFLAGS="-O2 -fopenmp"
export CXXFLAGS="-O2 -fopenmp"
export FCFLAGS="-O2 -fopenmp -fallow-argument-mismatch"
export FFLAGS="$FCFLAGS"

# ============================================================
# Linker search paths and libraries
# ============================================================

export LDFLAGS="-fopenmp -L$LIBNEGF_BUILD/src -L$NEGF_MPIFX_LIB -L$OPENBLAS_LIB"

# Libraries are kept separate from LDFLAGS so configure/make
# can place them after object files and static archives.
export BLAS_LIBS="-lopenblas"
export LAPACK_LIBS="-lopenblas"
export LIBS="-lopenblas"

# Used by project-specific configure.ac / Makefile.am if supported.
export NEGF_LIBS="-L$LIBNEGF_BUILD/src -lnegf -L$NEGF_MPIFX_LIB -lmpifx -lopenblas"

export BIGDFT_CONFIGURE_FLAGS="--enable-mpi --with-ext-linalg=-lopenblas"

# ============================================================
# Runtime paths
# ============================================================

for _dir in "$OPENBLAS_LIB" "$NEGF_MPIFX_LIB"; do
    case ":${LD_LIBRARY_PATH:-}:" in
        *":$_dir:"*) ;;
        *) export LD_LIBRARY_PATH="$_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
done

export LIBRARY_PATH="$NEGF_MPIFX_LIB:$OPENBLAS_LIB${LIBRARY_PATH:+:$LIBRARY_PATH}"
export CPATH="$LIBNEGF_INC:$LIBNEGF_MOD1:$LIBNEGF_MOD2:$MPIFX_INC${CPATH:+:$CPATH}"

# ============================================================
# pkg-config
# ============================================================

#export PKG_CONFIG_PATH="$NEGF_MPIFX_LIB/pkgconfig:$NEGF_MPIFX_LIB${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH=$NEGF_MPIFX_LIB:$NEGF_MPIFX_LIB/pkgconfig:/p/software/default/stages/2026/software/imkl/2025.2.0/compiler/2025.2/lib/pkgconfig:$HOME/pkgconfig-compat:$PKG_CONFIG_PATH

# ============================================================
# Diagnostics
# ============================================================

echo "BigDFT environment loaded"
echo "MAIN_DIR=$MAIN_DIR"
echo "BIGDFT_ROOT=$BIGDFT_ROOT"
echo "BIGDFT_SRC=$BIGDFT_SRC"
echo "BIGDFT_BUILD=$BIGDFT_BUILD"
echo "LIBNEGF_ROOT=$LIBNEGF_ROOT"
echo "LIBNEGF_INSTALL=$LIBNEGF_INSTALL"
echo "OPENBLAS_LIB=$OPENBLAS_LIB"
echo "CC=$CC"
echo "CXX=$CXX"
echo "FC=$FC"
echo "LDFLAGS=$LDFLAGS"
echo "BLAS_LIBS=$BLAS_LIBS"
echo "LAPACK_LIBS=$LAPACK_LIBS"
echo "LIBS=$LIBS"

# Verify that the expected libraries exist.
if [[ ! -f "$OPENBLAS_LIB/libopenblas.so" && ! -f "$OPENBLAS_LIB/libopenblas.a" ]]; then
    echo "WARNING: libopenblas.so/libopenblas.a not found under $OPENBLAS_LIB"
fi

