#!/usr/bin/env python3
"""Run frozen-H, finite-bias MoS2 transport through the LibNEGF Fortran driver."""

import argparse
import math
import os
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

import yaml


HARTREE_TO_EV = 27.2114
MATRIX_FILES = {
    "hamiltonian_sparse.mtx": "H.mtx",
    "overlap_sparse.mtx": "S.mtx",
}


def matrix_market_shape(path):
    with path.open("r", encoding="utf-8") as handle:
        if not handle.readline().strip().startswith("%%MatrixMarket"):
            raise ValueError("Invalid Matrix Market file: {}".format(path))
        for line in handle:
            line = line.strip()
            if not line or line.startswith("%"):
                continue
            fields = line.split()
            if len(fields) < 3:
                raise ValueError("Invalid Matrix Market dimensions in {}".format(path))
            return int(fields[0]), int(fields[1])
    raise ValueError("Missing Matrix Market dimensions in {}".format(path))


def read_int_list(path):
    try:
        return [
            int(value)
            for value in re.split(r"[,\s]+", path.read_text(encoding="utf-8").strip())
            if value
        ]
    except ValueError as exc:
        raise ValueError("Expected comma- or whitespace-separated integers in {}".format(path)) from exc


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Run two-terminal finite-bias transport with fixed BigDFT H/S matrices. "
            "This is not a self-consistent finite-bias calculation."
        )
    )
    parser.add_argument("--matrix-dir", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--regions-file", type=Path)
    parser.add_argument("--reorder-file", type=Path)
    parser.add_argument("--driver", type=Path, required=True, help="Compiled test_negf_transport_driver.")
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--mu-hartree", type=float, required=True, help="Equilibrium reference mu in Hartree.")
    parser.add_argument("--bias-v", type=float, required=True, help="Bias: (mu_left-mu_right)/e, in volts.")
    parser.add_argument("--kbt-hartree", type=float, default=0.001)
    parser.add_argument("--estep-hartree", type=float, default=0.001)
    parser.add_argument("--thermal-margin-kbt", type=float, default=10.0)
    parser.add_argument("--spin-degeneracy", type=float, choices=(1.0, 2.0), default=2.0)
    parser.add_argument("--mpi-ranks", type=int, default=2)
    parser.add_argument("--mpi-launcher", default="srun", help="Use srun on Slurm or mpirun.")
    parser.add_argument("--omp-threads", type=int, default=1)
    args = parser.parse_args()

    matrix_dir = args.matrix_dir.expanduser().resolve()
    driver = args.driver.expanduser().resolve()
    regions_file = (args.regions_file or matrix_dir / "regions.txt").expanduser().resolve()
    reorder_file = (args.reorder_file or matrix_dir / "reorder.txt").expanduser().resolve()
    run_dir = (
        args.run_dir.expanduser().resolve()
        if args.run_dir
        else matrix_dir / ("libnegf_fixed_bias_{}".format(datetime.now().strftime("%Y%m%d_%H%M%S")))
    )

    if not driver.is_file():
        raise FileNotFoundError("Transport driver not found: {}".format(driver))
    for path in (regions_file, reorder_file):
        if not path.is_file():
            raise FileNotFoundError("Partition file not found: {}".format(path))
    if args.mpi_ranks < 1 or args.omp_threads < 1:
        raise ValueError("mpi-ranks and omp-threads must be positive.")
    if not all(
        math.isfinite(value)
        for value in (
            args.mu_hartree,
            args.bias_v,
            args.kbt_hartree,
            args.estep_hartree,
            args.thermal_margin_kbt,
        )
    ):
        raise ValueError("Energy, bias, temperature, and grid parameters must be finite.")
    if args.kbt_hartree <= 0 or args.estep_hartree <= 0 or args.thermal_margin_kbt <= 0:
        raise ValueError("Temperature, energy step, and thermal margin must be positive.")
    if run_dir.exists() and any(run_dir.iterdir()):
        raise FileExistsError("Run directory is not empty: {}".format(run_dir))

    shapes = {}
    for source_name in MATRIX_FILES:
        source = matrix_dir / source_name
        if not source.is_file():
            raise FileNotFoundError("Required matrix not found: {}".format(source))
        shapes[source_name] = matrix_market_shape(source)
    if len(set(shapes.values())) != 1:
        raise ValueError("H and S dimensions differ: {}".format(shapes))
    nrow, ncol = next(iter(shapes.values()))
    if nrow != ncol:
        raise ValueError("H and S must be square, got {} x {}.".format(nrow, ncol))

    regions = read_int_list(regions_file)
    reorder = read_int_list(reorder_file)
    if len(regions) != 5 or regions[-1] != nrow or regions[0] <= 0:
        raise ValueError("Expected five cumulative regions ending at matrix dimension {}.".format(nrow))
    if any(left >= right for left, right in zip(regions, regions[1:])):
        raise ValueError("Region boundaries must be strictly increasing.")
    if len(reorder) != nrow or sorted(reorder) != list(range(nrow)):
        raise ValueError("reorder must be a permutation of all {} matrix indices.".format(nrow))

    mu_ev = args.mu_hartree * HARTREE_TO_EV
    mu_left_ev = mu_ev + args.bias_v / 2.0
    mu_right_ev = mu_ev - args.bias_v / 2.0
    mu_left_ha = mu_left_ev / HARTREE_TO_EV
    mu_right_ha = mu_right_ev / HARTREE_TO_EV
    margin_ha = args.thermal_margin_kbt * args.kbt_hartree
    emin = min(mu_left_ha, mu_right_ha) - margin_ha
    required_emax = max(mu_left_ha, mu_right_ha) + margin_ha
    emax = required_emax + args.estep_hartree

    input_data = {
        "chess": {
            "libnegf": {
                "regions": regions,
                "reorder": reorder,
                "mu_left": mu_left_ha,
                "mu_right": mu_right_ha,
                "kbt_t": args.kbt_hartree,
                "emin": emin,
                "emax": emax,
                "estep": args.estep_hartree,
                "spin_degeneracy": args.spin_degeneracy,
            }
        }
    }

    run_dir.mkdir(parents=True, exist_ok=True)
    for source_name, target_name in MATRIX_FILES.items():
        shutil.copy2(matrix_dir / source_name, run_dir / target_name)
    with (run_dir / "input.yaml").open("w", encoding="utf-8") as handle:
        yaml.safe_dump(input_data, handle, sort_keys=False)

    summary = [
        "method=fixed-H finite-bias coherent transport",
        "self_consistent=false",
        "matrix_dir={}".format(matrix_dir),
        "driver={}".format(driver),
        "matrix_dimension={}".format(nrow),
        "regions={}".format(regions),
        "mu_reference_hartree={:.12g}".format(args.mu_hartree),
        "bias_v={:.12g}".format(args.bias_v),
        "mu_left_hartree={:.12g}".format(mu_left_ha),
        "mu_right_hartree={:.12g}".format(mu_right_ha),
        "kbt_hartree={:.12g}".format(args.kbt_hartree),
        "emin_hartree={:.12g}".format(emin),
        "emax_hartree={:.12g}".format(emax),
        "required_emax_hartree={:.12g}".format(required_emax),
        "estep_hartree={:.12g}".format(args.estep_hartree),
        "spin_degeneracy={}".format(args.spin_degeneracy),
        "potential_profile=none; H and S remain frozen at the GS values",
    ]
    (run_dir / "run_summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")

    launcher = shutil.which(args.mpi_launcher)
    if launcher is None:
        raise FileNotFoundError("MPI launcher not found in PATH: {}".format(args.mpi_launcher))
    launcher_name = Path(launcher).name.lower()
    if launcher_name.startswith("srun"):
        command = [launcher, "--ntasks", str(args.mpi_ranks), str(driver)]
    else:
        command = [launcher, "-np", str(args.mpi_ranks), str(driver)]

    env = os.environ.copy()
    env["OMP_NUM_THREADS"] = str(args.omp_threads)
    print("Running: {}".format(" ".join(command)))
    print("Working directory: {}".format(run_dir))
    with (run_dir / "transport.stdout").open("w", encoding="utf-8") as stdout, (
        run_dir / "transport.stderr"
    ).open("w", encoding="utf-8") as stderr:
        result = subprocess.run(command, cwd=str(run_dir), env=env, stdout=stdout, stderr=stderr)

    if result.returncode != 0:
        tail = (run_dir / "transport.stderr").read_text(
            encoding="utf-8", errors="replace"
        ).splitlines()[-60:]
        raise RuntimeError(
            "Transport driver exited with status {}. Last stderr lines:\n{}".format(
                result.returncode, "\n".join(tail)
            )
        )
    for output_name in ("transmission.dat", "transport_result.txt"):
        if not (run_dir / output_name).is_file():
            raise FileNotFoundError("Driver did not create expected output: {}".format(output_name))
    print("Transport outputs: {}".format(run_dir))
    print((run_dir / "transport_result.txt").read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
