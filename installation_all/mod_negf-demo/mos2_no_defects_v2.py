#!/usr/bin/env python3
"""Run the five-plate MoS2 ground state and export a LibNEGF partition.

The GEN file is expected to contain five consecutive 108-atom plates. Plates
are assigned left-to-right from their x-coordinate centers; the transport
partition order follows Chain: MID, LEF:1, LEF:2, RIG:1, RIG:2.
"""

import json
import os
import shutil
from pathlib import Path

from ase.io import read

from BigDFT import Calculators as C
from BigDFT import Logfiles as lf
from BigDFT.Inputfiles import Inputfile
from BigDFT.Interop.ASEInterop import ase_to_bigdft
from BigDFT.PostProcessing import BigDFTool
from BigDFT.Systems import System
from BigDFT.UnitCells import UnitCell


GEN_FILE = Path("mos2_no_defects.gen")
RUN_DIR = Path("2_mos2_no_defects_v2")
RUN_NAME = "mos2_no_defects_v2"
PLATE_ATOM_COUNT = 108
PLATE_COUNT = 5

TRANSPORT_ORDER = ["MID:0", "LEF:1", "LEF:2", "RIG:1", "RIG:2"]
MATRIX_FILES = (
    "hamiltonian_sparse.mtx",
    "overlap_sparse.mtx",
    "density_kernel_sparse.mtx",
)


def build_fragmented_system(atoms):
    """Split the five GEN plate blocks into Chain-compatible fragments."""
    expected_atoms = PLATE_ATOM_COUNT * PLATE_COUNT
    if len(atoms) != expected_atoms:
        raise ValueError(
            "Expected {} atoms ({} plates x {}), found {} in {}.".format(
                expected_atoms, PLATE_COUNT, PLATE_ATOM_COUNT, len(atoms), GEN_FILE
            )
        )

    positions = atoms.get_positions()
    plates = []
    for plate_number in range(PLATE_COUNT):
        start = plate_number * PLATE_ATOM_COUNT
        stop = start + PLATE_ATOM_COUNT
        indices = list(range(start, stop))
        center_x = sum(float(positions[index][0]) for index in indices) / len(indices)
        plates.append((center_x, atoms[start:stop]))

    plates.sort(key=lambda item: item[0])
    x_centers = [center for center, _ in plates]
    if any(right <= left for left, right in zip(x_centers, x_centers[1:])):
        raise ValueError("Could not establish a unique left-to-right plate order by x.")

    spatial_labels = ["LEF:2", "LEF:1", "MID:0", "RIG:1", "RIG:2"]
    center_by_label = dict(zip(spatial_labels, x_centers))
    fragments_by_label = {
        label: ase_to_bigdft(plate)
        for label, (_, plate) in zip(spatial_labels, plates)
    }

    system = System()
    for label in TRANSPORT_ORDER:
        system[label] = fragments_by_label[label]

    cell_lengths = atoms.get_cell().lengths()
    system.cell = UnitCell(
        [float(cell_lengths[0]), float(cell_lengths[1]), 20.0],
        units="angstroem",
    )

    print("Plate centers along x (Angstrom):")
    for label in spatial_labels:
        print("  {}: {:.6f}".format(label, center_by_label[label]))
    print("Fragment sizes (atoms):")
    for label in TRANSPORT_ORDER:
        print("  {}: {}".format(label, len(system[label])))
    return system


def export_libnegf_partition(system, log, data_dir, output_dir):
    """Derive and save regions/reorder using BigDFT support-function metadata."""
    metadata_file = data_dir / "sparsematrix_metadata.dat"
    if not metadata_file.is_file():
        raise FileNotFoundError(
            "BigDFT support-function metadata is missing: {}".format(metadata_file)
        )

    tool = BigDFTool()
    fragment_indices = tool.get_frag_indices(system, log)

    order = []
    regions = []
    total = 0
    for label in TRANSPORT_ORDER:
        if label not in fragment_indices:
            raise KeyError("BigDFTool returned no support-function indices for {}.".format(label))
        indices = [int(index) for index in fragment_indices[label]]
        if not indices:
            raise ValueError("Fragment {} has no support functions.".format(label))
        order.extend(indices)
        total += len(indices)
        regions.append(total)
        print(
            "{}: {} atoms, {} support functions".format(
                label, len(system[label]), len(indices)
            )
        )

    if len(set(order)) != len(order):
        raise ValueError("Fragment support-function indices overlap.")
    if sorted(order) != list(range(total)):
        raise ValueError(
            "The fragment indices do not cover the support-function range 0..{}."
            .format(total - 1)
        )
    expected_total = getattr(log, "number_of_orbitals", None)
    if expected_total is not None and int(expected_total) != total:
        raise ValueError(
            "Fragments map to {} support functions, but the logfile reports {}."
            .format(total, expected_total)
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "regions.txt").write_text(
        ",".join(str(value) for value in regions) + "\n",
        encoding="utf-8",
    )
    (output_dir / "reorder.txt").write_text(
        "\n".join(str(value) for value in order) + "\n",
        encoding="utf-8",
    )
    partition = {
        "chess": {
            "libnegf": {
                "regions": regions,
                "reorder": order,
            }
        }
    }
    with (output_dir / "libnegf_partition.json").open("w", encoding="utf-8") as handle:
        json.dump(partition, handle, indent=2)
        handle.write("\n")

    return regions, order


def main():
    if not GEN_FILE.is_file():
        raise FileNotFoundError("Structure file not found: {}".format(GEN_FILE.resolve()))
    if RUN_DIR.exists() and any(RUN_DIR.iterdir()):
        raise FileExistsError(
            "Run directory is not empty: {}. Choose a new RUN_DIR/RUN_NAME "
            "to avoid mixing or overwriting calculation outputs.".format(
                RUN_DIR.resolve()
            )
        )

    atoms = read(str(GEN_FILE))
    system = build_fragmented_system(atoms)

    omp_threads = int(os.environ.get("SLURM_CPUS_PER_TASK", "1"))
    calculator = C.SystemCalculator(
        verbose=True,
        omp=omp_threads,
        mpi_run="srun",
        skip=False,
    )

    inp = Inputfile()
    inp.set_xc("PBE")
    inp.set_hgrid(0.42)
    inp.set_rmult([5.0, 8.0])
    inp.set_symmetry(False)
    inp["mix"] = {"norbsempty": 60}
    inp["import"] = "linear"
    inp["lin_general"] = {"subspace_diag": "yes"}
    inp["lin_basis_params"] = {"S": {"rloc": 8.0, "nbasis": 4}}
    inp["kpt"] = {"method": "mpgrid", "ngkpt": [1, 1, 1]}
    inp.write_support_functions_on_disk()

    calculator.run(
        input=inp,
        posinp=system.get_posinp(),
        name=RUN_NAME,
        run_dir=str(RUN_DIR),
    )

    log_path = RUN_DIR / "log-{}.yaml".format(RUN_NAME)
    if not log_path.is_file():
        raise FileNotFoundError("BigDFT logfile not found after the run: {}".format(log_path))
    log = lf.Logfile(str(log_path))
    if int(log.nat) != len(atoms):
        raise ValueError(
            "BigDFT logfile reports {} atoms, but the fragmented GEN system has {}."
            .format(log.nat, len(atoms))
        )

    data_dir = RUN_DIR / "data-{}".format(RUN_NAME)
    if not data_dir.is_dir():
        raise FileNotFoundError("BigDFT data directory not found: {}".format(data_dir))

    matrix_dir = RUN_DIR / "mos2_mtx"
    matrix_dir.mkdir(parents=True, exist_ok=True)
    for filename in MATRIX_FILES:
        source = data_dir / filename
        if not source.is_file():
            raise FileNotFoundError("Expected BigDFT matrix not found: {}".format(source))
        shutil.copy2(str(source), str(matrix_dir / filename))

    regions, order = export_libnegf_partition(
        system,
        log,
        data_dir,
        matrix_dir,
    )

    for filename in MATRIX_FILES:
        matrix_path = matrix_dir / filename
        with matrix_path.open("r", encoding="utf-8") as handle:
            if not handle.readline().strip().startswith("%%MatrixMarket"):
                raise ValueError("Invalid Matrix Market header: {}".format(matrix_path))
            for line in handle:
                line = line.strip()
                if not line or line.startswith("%"):
                    continue
                dimensions = [int(value) for value in line.split()[:2]]
                if dimensions != [len(order), len(order)]:
                    raise ValueError(
                        "{} has dimensions {}, expected {}x{}.".format(
                            matrix_path, dimensions, len(order), len(order)
                        )
                    )
                break
            else:
                raise ValueError("Missing Matrix Market dimensions: {}".format(matrix_path))

    print("Ground-state reference:")
    print("  atoms: {}".format(log.nat))
    print("  support functions: {}".format(log.number_of_orbitals))
    print("  Fermi level (Hartree): {}".format(log.fermi_level))
    print("  energy (Hartree): {}".format(log.energy))
    print("LibNEGF partition:")
    print("  regions: {}".format(regions))
    print("  reorder entries: {}".format(len(order)))
    print("  matrices and partition files: {}".format(matrix_dir.resolve()))
    print("  logfile: {}".format(log_path.resolve()))


if __name__ == "__main__":
    main()

