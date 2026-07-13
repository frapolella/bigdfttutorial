#bigdft-libnegf environment --> source env.sh (before compiling bigdft)

export CC=$(which mpicc)
export CXX=$(which mpicxx)
export FC=$(which mpifort)
export F77=$(which mpifort)
export LIBNEGF_INC=/home/francesco/bigdft-negf/pybigdfttest/libnegf/build/src/include
export LIBNEGF_LIB=/home/francesco/bigdft-negf/pybigdfttest/libnegf/build/src
export MPIFX_LIB=$CONDA_PREFIX/lib
export CPPFLAGS="-I$LIBNEGF_INC"
export CFLAGS="-I$LIBNEGF_INC"
export CXXFLAGS="-I$LIBNEGF_INC"
export FCFLAGS="-fopenmp -I$LIBNEGF_INC"
export FFLAGS="-fopenmp _I$LIBNEGF_INC"
export LDFLAGS="-fopenmp \
-L$LIBNEGF_LIB -lnegf \
-L$MPIFX_LIB -lmpifx"
export LIBRARY_PATH=$LIBNEGF_LIB:$MPIFX_LIB:$LIBRARY_PATH
export LD_LIBRARY_PATH=$LIBNEGF_LIB:$MPIFX_LIB:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$LIBNEGF_LIB/pkgconfig:$PKG_CONFIG_PATH # if *.pc file doesn't exist nothing happen

#controll
echo "CC=$CC"
echo "CXX=$CXX"
echo "FC=$FC"
echo "F77=$F77"

echo "LIBNEGF_INC=$LIBNEGF_INC"
echo "LIBNEGF_LIB=$LIBNEGF_LIB"

echo "CPPFLAGS=$CPPFLAGS"
echo "FCFLAGS=$FCFLAGS"
echo "LDFLAGS=$LDFLAGS"

echo "LIBRARY_PATH=$LIBRARY_PATH"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

which mpicc
which mpicxx
which mpifort
