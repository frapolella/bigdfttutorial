#import numpy as np
from ase.io import read

from BigDFT.Interop.ASEInterop import ase_to_bigdft
from BigDFT.Systems import System
from BigDFT.UnitCells import UnitCell
from BigDFT.IO import XYZReader
from BigDFT.Fragments import Fragment
from BigDFT.Inputfiles import Inputfile
from BigDFT import Calculators as C

# ==========================
# BUILDING SYSTEM
# ==========================

atoms = read("mos2.cif")
atoms *= [1, 1, 1]

sys = System()
sys["SUR:1"] = ase_to_bigdft(atoms)

sys.cell = UnitCell(
    [
        float(atoms.cell[0, 0]),
        float("inf"),
        float(atoms.cell[2, 2])
    ],
    units="angstroem"
)

with XYZReader("xclustero") as ifile:
    sys["ABS:2"] = Fragment(xyzfile=ifile)

# ==========================
# MD INPUT
# ==========================

inp = Inputfile()

inp.set_xc("LDA")
inp.set_hgrid(0.5)

inp["md"] = {
    "mdsteps": 2,
    "timestep": 15.6706866726,
    "temperature": 330.0,
    "print_frequency": 1
}

# ==========================
# CALCULATOR
# ==========================

study = C.SystemCalculator(
    verbose=True,
    omp=4,
    mpi_run="srun",
    skip=False
)

# ==========================
# MD RUN
# ==========================

log_md = study.run(
    input=inp,
    posinp=sys.get_posinp(),
    name="mdtest",
    run_dir="mdtest"
)

print("MD ENDED")
