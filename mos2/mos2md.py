#working optimization and molecular dynamic script
#imports

from ase.io import read
from BigDFT.Interop.ASEInterop import ase_to_bigdft
from BigDFT.Systems import System
from BigDFT.UnitCells import UnitCell
from BigDFT.IO import XYZReader
from BigDFT.Fragments import Fragment
from BigDFT.Inputfiles import Inputfile
from BigDFT import Calculators as C

#calculator settings
study = C.SystemCalculator(verbose=True,
omp=4,
mpi_run="srun",
skip=False)

#build a system --> define the sys into 2 fragments (MoS2 crystal and O2 molecules)

atoms = read("mos2.cif")
atoms *= [1, 1, 1]
sys = System()
sys["SUR:1"] = ase_to_bigdft(atoms)
sys.cell = UnitCell(
[
float(atoms.cell[0,0]),
float("inf"),
float(atoms.cell[2,2])
],
units="angstroem"
)

with XYZReader("xclustero") as ifile:
 sys["ABS:2"] = Fragment(xyzfile=ifile)

#input settings
#optimization setting (ground state)
inp = Inputfile()
inp.set_xc("LDA")
inp.set_hgrid(0.5)
inp.optimize_geometry(
 method="SQNM",
 nsteps=3,
 betax=0.5
)

#optimization log settings
log_opt = study.run(
 input=inp,
 posinp=sys.get_posinp(),
 name="opttest",
 run_dir="opttest")

#update position --> molecular dynamics starts from last optimization step
sys.update_positions_from_dict(
 log_opt.log["Atomic structure"])

#delete geopt
del inp["geopt"]

#molecular dynamic settings
inp["md"] = {"mdsteps": 3,
"timestep": 15.6706866,
"temperature": 330.0,
"print_frequency":1}

#molecular dynamic log settings
log_md = study.run(input=inp,
posinp=sys.get_posinp(),
name="2mdtest",
run_dir="2mdtest")

print("END")
