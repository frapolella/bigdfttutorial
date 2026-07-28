If the system is smaller it's possible to increase the monomeric units.
Try setting:                                         
           atoms *= [1, 1, 1] ---> atoms *= [5, 5, 2]
or add an oxigen cluster in /Database/XYZs.

mos2.py has molecular dynamic issues
mos2md.py solved molecular dynamic problems

In this directory are presentes test files to run optimization and molecular dynamic simulation.
Both files use MoS2 crystalline structure as base for calculus (fragment 1)and adds 5 molecules of O2 on top
Is possible to change the crystalline structure, the optimization, md steps and other parameters just by edit the python files:

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
