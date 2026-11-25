# Setup Codes

First, you should compile libNEGF somewhere. Then get a specific branch of
bigdft.
```
git clone git@gitlab.com:l_sim/bigdft-suite.git
cd bigdft-suite
git checkout libnegf
```
You can understand the code changes by looking at:
```
https://gitlab.com/l_sim/bigdft-suite/-/blob/libnegf/chess/bigpoly/bigpoly_negf.f90?ref_type=heads
```


Compile libNEGF. You should add the include path and lib path to libNEGF
into your rcfile.

Compile the driver that does one shot calculations. For me I did something
like:
```
mpif90 test_negf_driver.f90 -o test_driv \
-I /home/francesco/bigdft-negf/pybigdfttest/bigdft/build/install/include/ \
-L /home/francesco/bigdft-negf/pybigdfttest/bigdft/build/install/lib -lfutile-1 -lyaml -lNTPoly -lCheSS-1 \
-L /home/francesco/bigdft-negf/pybigdfttest/negf/src/build/src/include/ /home/francesco/bigdft-negf/pybigdfttest/negf/src/build/src/ -lnegf -lmpifx \
 -framework Accelerate  -fopenmp
```

Setup an environment with python and PyBigDFT.
```
pip install PyBigDFT
```
Now you can work through the included notebook.
