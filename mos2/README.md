In this directory are presentes test files to run optimization and molecular dynamic simulation.
Both files use MoS2 crystalline structure as base for calculus (fragment 1)and adds 5 molecules of O2 on top.
mos2.py has molecular dynamic issues
mos2md.py solved molecular dynamic problems
In order to run the calculus is mandatory to add xclustero.xyz into:
bigdft-suite/build/install/lib/python3.13/site-packages/BigDFT/Database/XYZs/
This dir has been created after BigDFT compilation.

justmd.py -->
 1) calculates molecular ground state
 2) creates a mdtest dir
 3) launch a small md simulation

mos2md -->
 1) creates the opttest dir
 2) launch optimization calculus
 3) remove geopt file
 4) creates mdtest dir
 5) launch molecular dyn simulation

Is possible to add changes into the crystalline structure, the optimization process, md steps and other parameters by editing the python files:

#build a system
atoms *= [1, 1, 1] --> crystalline structure

#input settings
#optimization setting (ground state)
inp.optimize_geometry(...
nsteps=3
...
) --> method, nsteps and betax

#molecular dynamic settings
inp["md"] = {"mdsteps": 3,
"timestep": 15.6706866,
"temperature": 330.0,
"print_frequency":1}
