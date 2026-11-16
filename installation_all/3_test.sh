#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# 1. Main directories
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export MAIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export SOFT_ROOT="$MAIN_DIR"

export LIBNEGF_ROOT="$MAIN_DIR/libnegf"
export LIBNEGF_BUILD="$LIBNEGF_ROOT/build"
export LIBNEGF_BUILD_SRC="$LIBNEGF_BUILD/src"
export LIBNEGF_INSTALL="$MAIN_DIR/libnegf-install"
export LIBNEGF_LIB64="$LIBNEGF_INSTALL/lib64"
export LIBNEGF_MOD_DIR="$LIBNEGF_INSTALL/include/modfiles"
export MPIFX_MOD_DIR="$LIBNEGF_INSTALL/include/mpifx/modfiles"

export BIGDFT_ROOT="$MAIN_DIR/bigdft-suite"
export BIGDFT_SRC="$BIGDFT_ROOT/src"
export BIGDFT_BUILD="$BIGDFT_ROOT/build"
export BIGDFT_INSTALL="$BIGDFT_BUILD/install"

LIBNEGF_ENV="$SCRIPT_DIR/libnegf_env.sh"
BIGDFT_ENV="$SCRIPT_DIR/bigdft_env.sh"

export OPENBLAS_ROOT="/p/software/default/stages/2026/software/OpenBLAS/0.3.30-GCC-14.3.0"
export OPENBLAS_LIB="$OPENBLAS_ROOT/lib"

# ============================================================
# 2. Logging
# ============================================================

LOG_FILE="$SCRIPT_DIR/installation.log"

mkdir -p "$SCRIPT_DIR"
touch "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "ERRORE: $*"
    exit 1
}

log "Avvio installer libNEGF + BigDFT"
log "SCRIPT_DIR      = $SCRIPT_DIR"
log "MAIN_DIR        = $MAIN_DIR"
log "LIBNEGF_ROOT    = $LIBNEGF_ROOT"
log "LIBNEGF_BUILD   = $LIBNEGF_BUILD"
log "LIBNEGF_BUILD_SRC = $LIBNEGF_BUILD_SRC"
log "LIBNEGF_INSTALL = $LIBNEGF_INSTALL"
log "LIBNEGF_LIB64   = $LIBNEGF_LIB64"
log "LIBNEGF_MOD_DIR = $LIBNEGF_MOD_DIR"
log "MPIFX_MOD_DIR   = $MPIFX_MOD_DIR"
log "BIGDFT_ROOT     = $BIGDFT_ROOT"
log "BIGDFT_SRC      = $BIGDFT_SRC"
log "BIGDFT_BUILD    = $BIGDFT_BUILD"
log "BIGDFT_INSTALL  = $BIGDFT_INSTALL"

# ============================================================
# 3. Load JUWELS modules
# ============================================================

log "Caricamento moduli JUWELS"

if ! type module >/dev/null 2>&1; then
    die "Il comando 'module' non è disponibile. Avvia lo script in una shell JUWELS con Lmod inizializzato."
fi

load_module() {
    local module_name="$1"

    log "Caricamento modulo: $module_name"

    if module load "$module_name"; then
        log "Modulo caricato: $module_name"
    else
        die "Impossibile caricare il modulo: $module_name"
    fi
}

load_module Stages/2026
load_module GCCcore/14.3.0
load_module GCC/14.3.0
load_module CMake/3.31.8
load_module OpenMPI/5.0.8
load_module OpenBLAS/0.3.30
load_module Doxygen/1.14.0
load_module Python/3.13.5
#load_module CUDA-Python/12 #juwels_cluster
load_module CUDA/13 #juwels_booster
load_module ASE/3.26.0
load_module PyYAML/6.0.2
load_module tbb/2022.2.0

command -v mpicc >/dev/null 2>&1 || die "mpicc non trovato"
command -v mpicxx >/dev/null 2>&1 || die "mpicxx non trovato"
command -v mpifort >/dev/null 2>&1 || die "mpifort non trovato"
command -v cmake >/dev/null 2>&1 || die "cmake non trovato"
command -v python >/dev/null 2>&1 || die "python non trovato"
command -v python3 >/dev/null 2>&1 || die "python3 non trovato"

[[ -d "$OPENBLAS_LIB" ]] ||
    die "Directory OpenBLAS non trovata: $OPENBLAS_LIB"

log "Moduli caricati e verificati"

trap 'die "Errore alla linea $LINENO durante: $BASH_COMMAND"' ERR

# ============================================================
# 4. Clone and build libNEGF
# ============================================================

log "Preparazione libNEGF"

if [[ ! -d "$LIBNEGF_ROOT/.git" ]]; then
    if [[ -e "$LIBNEGF_ROOT" ]]; then
        die "$LIBNEGF_ROOT esiste ma non è un repository Git. Verificare manualmente."
    fi

    git clone https://github.com/libnegf/libnegf.git "$LIBNEGF_ROOT"
else
    log "Repository libNEGF già presente: salto il clone"
fi

mkdir -p "$LIBNEGF_BUILD" "$LIBNEGF_INSTALL"

[[ -f "$LIBNEGF_ENV" ]] ||
    die "File ambiente libNEGF non trovato: $LIBNEGF_ENV"

log "Caricamento ambiente libNEGF"
source "$LIBNEGF_ENV"

log "Configurazione CMake libNEGF"

cmake -S "$LIBNEGF_ROOT" -B "$LIBNEGF_BUILD" \
    -DCMAKE_INSTALL_PREFIX="$LIBNEGF_INSTALL" \
    -DBLAS_LIBRARY=openblas \
    -DBLAS_LIBRARY_DIR="$OPENBLAS_LIB" \
    -DLAPACK_LIBRARY=openblas \
    -DLAPACK_LIBRARY_DIR="$OPENBLAS_LIB"

log "Compilazione libNEGF"
cmake --build "$LIBNEGF_BUILD" --parallel 4

log "Installazione libNEGF"
cmake --install "$LIBNEGF_BUILD"

[[ -f "$LIBNEGF_INSTALL/lib64/libnegf.a" ]] ||
    die "libnegf.a non trovata in $LIBNEGF_INSTALL/lib64"

[[ -f "$LIBNEGF_BUILD_SRC/libnegf.a" ]] ||
    die "libnegf.a non trovata in $LIBNEGF_BUILD_SRC"

[[ -f "$LIBNEGF_LIB64/libmpifx.a" ]] ||
    die "libmpifx.a non trovata in $LIBNEGF_LIB64"

[[ -f "$LIBNEGF_MOD_DIR/libnegf.mod" ]] ||
    die "libnegf.mod non trovato in $LIBNEGF_MOD_DIR"

[[ -f "$MPIFX_MOD_DIR/libmpifx_module.mod" ]] ||
    die "Moduli Fortran MPIFX non trovati in $MPIFX_MOD_DIR"

log "Librerie e moduli libNEGF verificati"

# ============================================================
# 5. Clone BigDFT and checkout branch libnegf
# ============================================================

log "Preparazione sorgenti BigDFT"

mkdir -p "$BIGDFT_ROOT"

if [[ ! -d "$BIGDFT_SRC/.git" ]]; then
    if [[ -e "$BIGDFT_SRC" ]]; then
        die "$BIGDFT_SRC esiste ma non contiene un repository Git. Verificare manualmente."
    fi

    CLONE_DIR="$BIGDFT_ROOT/bigdft-suite"

    if [[ -e "$CLONE_DIR" ]]; then
        die "Directory di clone già esistente: $CLONE_DIR"
    fi

    git clone https://gitlab.com/l_sim/bigdft-suite "$CLONE_DIR"

    git -C "$CLONE_DIR" checkout libnegf
    mv "$CLONE_DIR" "$BIGDFT_SRC"
else
    log "Sorgenti BigDFT già presenti"

    CURRENT_BRANCH="$(git -C "$BIGDFT_SRC" branch --show-current)"
    log "Branch corrente: $CURRENT_BRANCH"

    if [[ "$CURRENT_BRANCH" != "libnegf" ]]; then
        git -C "$BIGDFT_SRC" checkout libnegf
    fi
fi

[[ -f "$BIGDFT_SRC/Installer.py" ]] ||
    die "Installer.py non trovato in $BIGDFT_SRC"

# ============================================================
# 6. Patch Makefile.am and input_variables_definition.yaml
# ============================================================

log "Aggiornamento Makefile.am e input_variables_definition.yaml"

export BIGDFT_CORE_MAKEFILE="$BIGDFT_SRC/bigdft/src/Makefile.am"
export WRAPPERS_MAKEFILE="$BIGDFT_SRC/bigdft/tests/libs/wrappers/Makefile.am"
export BIGPOLY_MAKEFILE="$BIGDFT_SRC/chess/bigpoly/Makefile.am"
export BIGDFT_INPUT_YAML="$BIGDFT_SRC/bigdft/src/input_variables_definition.yaml"

for FILE in \
    "$BIGDFT_CORE_MAKEFILE" \
    "$WRAPPERS_MAKEFILE" \
    "$BIGPOLY_MAKEFILE" \
    "$BIGDFT_INPUT_YAML"
do
    [[ -f "$FILE" ]] || die "File non trovato: $FILE"
done

export LIBNEGF_BUILD_SRC
export LIBNEGF_LIB64
export LIBNEGF_MOD_DIR
export MPIFX_MOD_DIR

python3 - <<'PY'
import os
import re
from pathlib import Path

BACKSLASH = chr(92)

def split_line_ending(line):
    if line.endswith("\r\n"):
        return line[:-2], "\r\n"
    if line.endswith("\n"):
        return line[:-1], "\n"
    return line, ""

def statement_end(lines, start):
    end = start
    while True:
        body, _ = split_line_ending(lines[end])
        if not body.rstrip().endswith(BACKSLASH):
            return end
        end += 1
        if end >= len(lines):
            raise RuntimeError("Continuazione Makefile incompleta a fine file")

def extend_assignment(path, assignment_pattern, expected_count, required_tokens, flags):
    path = Path(path)
    lines = path.read_text().splitlines(keepends=True)

    starts = []
    for index, line in enumerate(lines):
        body, _ = split_line_ending(line)
        if assignment_pattern.match(body):
            starts.append(index)

    if len(starts) != expected_count:
        raise RuntimeError(
            f"Attese {expected_count} assegnazioni in {path}, trovate {len(starts)}"
        )

    changed = 0

    for start in reversed(starts):
        end = statement_end(lines, start)
        block = "".join(lines[start:end + 1])

        for token in required_tokens:
            if token not in block:
                raise RuntimeError(
                    f"Assegnazione non riconosciuta in {path}:{start + 1}; "
                    f"manca {token!r}"
                )

        present = [flag in block for flag in flags]
        if all(present):
            continue
        if any(present):
            raise RuntimeError(
                f"Blocco di link parzialmente presente in {path}:{start + 1}; "
                "controllare il file manualmente"
            )

        body, newline = split_line_ending(lines[end])
        if not newline:
            newline = "\n"

        if not body.rstrip().endswith(BACKSLASH):
            lines[end] = body.rstrip() + " " + BACKSLASH + newline

        additions = []
        for index, flag in enumerate(flags):
            continuation = " " + BACKSLASH if index < len(flags) - 1 else ""
            additions.append(f"       {flag}{continuation}{newline}")

        lines[end + 1:end + 1] = additions
        changed += 1

    if changed:
        path.write_text("".join(lines))

    print(
        f"{path}: "
        + (f"aggiornato ({changed} assegnazioni)" if changed else "già aggiornato")
    )

def set_module_include_flags(path, module_dirs):
    path = Path(path)
    content = path.read_text()

    if "bigpoly_negf.f90" not in content:
        raise RuntimeError(
            f"{path} non elenca bigpoly_negf.f90; "
            "non applico le directory dei moduli a un target inatteso"
        )

    begin = "# BEGIN LIBNEGF MODULE INCLUDE PATHS"
    end = "# END LIBNEGF MODULE INCLUDE PATHS"

    if content.count(begin) != content.count(end) or content.count(begin) > 1:
        raise RuntimeError(f"Marker dei moduli incompleti o duplicati in {path}")

    if content.count(begin) == 1:
        pattern = re.compile(
            rf"(?ms)^{re.escape(begin)}\r?\n.*?^{re.escape(end)}\r?\n?"
        )
        content, removed = pattern.subn("", content)
        if removed != 1:
            raise RuntimeError(f"Impossibile aggiornare il blocco in {path}")

    block = (
        f"{begin}\n"
        f"AM_FCFLAGS += -I{module_dirs[0]} -I{module_dirs[1]}\n"
        f"{end}\n"
    )

    path.write_text(content.rstrip() + "\n\n" + block)
    print(f"{path}: directory dei moduli Fortran aggiornate")

def line_body(line):
    return split_line_ending(line)[0]

def section_bounds(lines, header_index):
    header = line_body(lines[header_index])
    section_indent = len(header) - len(header.lstrip(" "))
    end = len(lines)

    for index in range(header_index + 1, len(lines)):
        body = line_body(lines[index])
        stripped = body.strip()

        if not stripped or stripped.startswith("#"):
            continue

        indent = len(body) - len(body.lstrip(" "))
        if indent <= section_indent:
            end = index
            break

    return header_index + 1, end, section_indent

def find_exact_indices(lines, start, end, expected_lines):
    bodies = [line_body(line) for line in lines]
    matches = []

    for index in range(start, end - len(expected_lines) + 1):
        if bodies[index:index + len(expected_lines)] == expected_lines:
            matches.append(index)

    return matches

def find_direct_key(lines, start, end, key, indent):
    pattern = re.compile(rf"^{re.escape(' ' * indent)}{re.escape(key)}:")
    return [
        index
        for index in range(start, end)
        if pattern.match(line_body(lines[index]))
    ]

def add_yaml_entries(path):
    path = Path(path)
    lines = path.read_text().splitlines(keepends=True)
    bodies = [line_body(line) for line in lines]

    # Individua la voce lin_basis_params tramite la riga Ni specifica.
    ni_basis = "    Ni: { nbasis: 10, rloc: 8.0 }"
    basis_matches = [i for i, body in enumerate(bodies) if body == ni_basis]

    if len(basis_matches) != 1:
        raise RuntimeError(
            f"Attesa una sola riga {ni_basis!r}, trovate {len(basis_matches)}"
        )

    ni_basis_index = basis_matches[0]
    basis_headers = [
        i for i, body in enumerate(bodies[:ni_basis_index])
        if body == "  lin_basis_params:"
    ]
    if not basis_headers:
        raise RuntimeError(
            "Trovata la riga Ni, ma non la precedente sezione "
            "'  lin_basis_params:'"
        )

    basis_header_index = basis_headers[-1]
    basis_start, basis_end, _ = section_bounds(lines, basis_header_index)

    if not basis_start <= ni_basis_index < basis_end:
        raise RuntimeError(
            "La riga Ni individuata non appartiene alla sezione lin_basis_params attesa"
        )

    expected_basis_mo = "    Mo: { nbasis: 13, rloc: 7.5 }"
    basis_mo_indices = find_direct_key(
        lines, basis_start, basis_end, "Mo", indent=4
    )

    if basis_mo_indices:
        if len(basis_mo_indices) != 1 or bodies[basis_mo_indices[0]] != expected_basis_mo:
            raise RuntimeError(
                "Esiste già una voce Mo diversa o duplicata in lin_basis_params"
            )
        print("lin_basis_params: voce Mo già presente")
    else:
        _, newline = split_line_ending(lines[ni_basis_index])
        lines.insert(
            ni_basis_index + 1,
            expected_basis_mo + (newline or "\n")
        )
        print("lin_basis_params: aggiunta voce Mo")

    # Individua ig_occupation tramite l'anchor Fe specifico indicato.
    ig_anchor = [
        "  ig_occupation:",
        "    Fe:",
        "      3s: 2.0",
        "      3p: 6.0",
    ]
    ig_headers = find_exact_indices(lines, 0, len(lines), ig_anchor)

    if len(ig_headers) != 1:
        raise RuntimeError(
            "Atteso un solo anchor ig_occupation/Fe/3s/3p, "
            f"trovati {len(ig_headers)}"
        )

    ig_header_index = ig_headers[0]
    ig_start, ig_end, _ = section_bounds(lines, ig_header_index)

    ni_occupation = [
        "    Ni:",
        "      3s: 2.0",
        "      3p: 6.0",
        "      3d: 8.0",
        "      4s: 2.0",
    ]
    ni_matches = find_exact_indices(lines, ig_start, ig_end, ni_occupation)

    if len(ni_matches) != 1:
        raise RuntimeError(
            "Atteso un solo blocco Ni specificato in ig_occupation, "
            f"trovati {len(ni_matches)}"
        )

    mo_occupation = [
        "    Mo:",
        "      4s: 2.0",
        "      4p: 6.0",
        "      4d: 5.0",
        "      5s: 1.0",
        "      5p: 0.0",
    ]
    mo_matches = find_exact_indices(lines, ig_start, ig_end, mo_occupation)
    mo_keys = find_direct_key(lines, ig_start, ig_end, "Mo", indent=4)

    if mo_matches:
        if len(mo_matches) != 1 or len(mo_keys) != 1:
            raise RuntimeError("Voce Mo duplicata in ig_occupation")
        print("ig_occupation: voce Mo già presente")
    else:
        if mo_keys:
            raise RuntimeError(
                "Esiste già una voce Mo diversa in ig_occupation"
            )

        insert_at = ni_matches[0] + len(ni_occupation)
        _, newline = split_line_ending(lines[ni_matches[0]])
        newline = newline or "\n"
        lines[insert_at:insert_at] = [
            entry + newline for entry in mo_occupation
        ]
        print("ig_occupation: aggiunta voce Mo")

    path.write_text("".join(lines))
    print(f"{path}: verificato/aggiornato")

link_flags = [
    f"-L{os.environ['LIBNEGF_BUILD_SRC']}",
    "-lnegf",
    f"-L{os.environ['LIBNEGF_LIB64']}",
    "-lmpifx",
]

extend_assignment(
    os.environ["BIGDFT_CORE_MAKEFILE"],
    re.compile(r"^\s*bigdft_deps\s*\+=\s*@LIB_BIGDFT_DEPS@(?:\s|$)"),
    expected_count=2,
    required_tokens=["@LIB_BIGDFT_DEPS@"],
    flags=link_flags,
)

extend_assignment(
    os.environ["WRAPPERS_MAKEFILE"],
    re.compile(r"^\s*projection_LDADD\s*="),
    expected_count=1,
    required_tokens=[
        "$(bigdft_library)",
        "@LIB_FUTILE_LIBS@",
        "@LIB_PSOLVER_LIBS@",
    ],
    flags=link_flags,
)

set_module_include_flags(
    os.environ["BIGPOLY_MAKEFILE"],
    [
        os.environ["LIBNEGF_MOD_DIR"],
        os.environ["MPIFX_MOD_DIR"],
    ],
)

add_yaml_entries(os.environ["BIGDFT_INPUT_YAML"])
PY

log "Verifica delle modifiche ai Makefile.am e al file YAML"

grep -n -A5 'bigdft_deps += @LIB_BIGDFT_DEPS@' "$BIGDFT_CORE_MAKEFILE" ||
    die "Non trovo le assegnazioni bigdft_deps aggiornate"

grep -n -A5 'projection_LDADD' "$WRAPPERS_MAKEFILE" ||
    die "Non trovo projection_LDADD aggiornato"

grep -n -A2 'LIBNEGF MODULE INCLUDE PATHS' "$BIGPOLY_MAKEFILE" ||
    die "Non trovo le directory dei moduli in $BIGPOLY_MAKEFILE"

grep -n -A2 'Mo: { nbasis: 13, rloc: 7.5 }' "$BIGDFT_INPUT_YAML" ||
    die "Voce Mo non trovata in lin_basis_params"

grep -n -A5 '^    Mo:$' "$BIGDFT_INPUT_YAML" ||
    die "Voce Mo non trovata in ig_occupation"

log "Patch completata"

# ============================================================
# 7. Configure and build BigDFT
# ============================================================

log "Configurazione dell'ambiente BigDFT"

[[ -f "$BIGDFT_ENV" ]] ||
    die "File ambiente BigDFT non trovato: $BIGDFT_ENV"

mkdir -p "$BIGDFT_BUILD"
cd "$BIGDFT_BUILD"

log "Esecuzione Installer.py autogen (un input Y)"

set +e
source "$BIGDFT_ENV"
printf 'Y\n' | python ../src/Installer.py autogen
status=${PIPESTATUS[1]}
set -e

if [[ "$status" -ne 0 ]]; then
    die "Installer.py autogen è fallito con codice $status"
fi

source "$BIGDFT_ENV"

echo "===== MODULI PRIMA DI BUILD ====="
module list 2>&1 || true

echo "===== COMPILATORI ====="
command -v gcc
command -v mpicc
command -v mpifort
command -v cmake

echo "===== VARIABILI MPI ====="
echo "LOADEDMODULES=${LOADEDMODULES:-<vuoto>}"
echo "PATH=$PATH"

log "Esecuzione Installer.py build -c (un input Y)"

set +e
source "$BIGDFT_ENV"
printf 'Y\n' | python ../src/Installer.py build -c
status=${PIPESTATUS[1]}
set -e

if [[ "$status" -ne 0 ]]; then
    die "Installer.py build -c è fallito con codice $status"
fi

# ============================================================
# 8. Final checks
# ============================================================

log "Verifica installazione BigDFT"

[[ -d "$BIGDFT_INSTALL" ]] ||
    die "Directory di installazione BigDFT non trovata: $BIGDFT_INSTALL"

log "Installazione completata"
log "libNEGF install: $LIBNEGF_INSTALL"
log "BigDFT install:  $BIGDFT_INSTALL"
log "Log:             $LOG_FILE"
