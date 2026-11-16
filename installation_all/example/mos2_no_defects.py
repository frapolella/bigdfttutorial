#working optimization and molecular dynamic script


#imports
import os
from ase.io import read
from BigDFT.Interop.ASEInterop import ase_to_bigdft
from BigDFT.Systems import System
from BigDFT.UnitCells import UnitCell
from BigDFT.IO import XYZReader
from BigDFT.Fragments import Fragment
from BigDFT.Inputfiles import Inputfile
from BigDFT import Calculators as C
from BigDFT import Logfiles as lf

#calculator settings
study = C.SystemCalculator(verbose=True,
omp=int(os.environ["SLURM_CPUS_PER_TASK"]),
mpi_run="srun",
skip=False)


atoms = read("mos2_no_defects.gen")
#atoms *= [1, 1, 1]
sys = System()
sys["SUR:1"] = ase_to_bigdft(atoms)
#sys.cell = UnitCell(None) #--> free pbc
#sys.cell = UnitCell(atoms.get_cell(), units="angstroem") #--> pbc 3d
cell_lengths = atoms.get_cell().lengths()
sys.cell = UnitCell([float(cell_lengths[0]), float(cell_lengths[1]), 20.0], units="angstroem") #--> pbc 2d
#sys.cell = UnitCell(
#[
#float(atoms.cell[0,0]),
#float(atoms.cell[1,1]),
#float(atoms.cell[2,2]),
#],
#units="angstroem")

#is it true?
print(sys.get_posinp())
print()

print("="*60)

print(atoms)
print()

print("Cell:")
print(atoms.cell)
print()

print("PBC:")
print(atoms.pbc)
print()

print("Total number of atoms:", len(atoms))


#input settings
#optimization setting (ground state)
inp = Inputfile()
inp.set_xc("PBE")
inp.set_hgrid(.42) #--> set up the grid step for the basis set spatial expansion
inp.set_rmult([5.0, 8.0]) #--> set up the basis set spatial expansion
inp.set_symmetry(False) #--> no bc for bulk
inp["mix"] = {"norbsempty":60}
inp["import"]= "linear"
inp['lin_general'] = {'subspace_diag': 'yes'} #--> DOS
inp["lin_basis_params"] = {
"S": {"rloc": 8.0, "nbasis": 4}
} #rloc 7.5
#brillouin k points
inp["kpt"] = {"method":"mpgrid", "ngkpt":[1,1,1]}

#write support function
inp.write_support_functions_on_disk()
#convergence of electronic density
#inp["dft"] = {"gnrm_cv": 1e-6} #----> generates error ---> Full Grid Arrays (MB)   : 199

optimize input
#inp.optimize_geometry(
# method="BFGS",
# nsteps=5,
# betax=0.5)


#optimization log settings
log_opt = study.run(
 input=inp,
 posinp=sys.get_posinp(),
 name="2_test_linear_0.42",
 run_dir="2_test_linear_0.42")

#logfiles
logs = lf.Logfile("2_test_linear_0.42/log-2_test_linear_0.42.yaml")
dos = logs.get_dos(label="MoS2")
ax = dos.plot(sigma=0.15)
ax.figure.savefig("hgrid_0.42_MoS2.png", dpi=300)


#energy = logs.energy
#evals = logs.evals
#fermi_level=logs.fermi_level
#nkpt = logs.nkpt
#system_charge = logs.system_charge
#number_f_orbitals = logs.number_of_orbitals
#HOMO=logs.HOMO
#LUMO=logs.LUMO
#band_gap=logs.band_gap

print("Number of atoms:", logs.nat)
print("Energy:", logs.energy)
print("Fermi level:", logs.fermi_level)
print("Number of orbitals:", logs.number_of_orbitals)
print("Orbitals autovalues:", logs.evals)
print("Number of k-points:", logs.nkpt)
print("Spin polarization:", logs.spin_polarization)
print("System charge:", logs.system_charge)
print("Maximum force:", logs.forcemax)
print("Symmetry:", logs.symmetry)

print("GROUND STATE ACHIEVED")
