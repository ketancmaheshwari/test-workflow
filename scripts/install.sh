#!/usr/bin/env bash
# =============================================================================
# install_hpc_pkgs.sh
# Installs TensorFlow, mpi4py, and RDKit on Ubuntu
# Tested on Ubuntu 20.04 / 22.04 / 24.04
# Usage: chmod +x install_hpc_pkgs.sh && sudo ./install_hpc_pkgs.sh
# =============================================================================

set -euo pipefail

# --- Colors ------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Root check --------------------------------------------------------------
[[ $EUID -ne 0 ]] && error "Please run as root (sudo)."

# =============================================================================
# 1. System dependencies
# =============================================================================
info "Updating apt and installing system dependencies..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    build-essential \
    libopenmpi-dev \
    openmpi-bin \
    openmpi-common \
    libssl-dev \
    libffi-dev \
    curl \
    wget \
    git

# =============================================================================
# 2. Create a virtual environment (keeps the system Python clean)
# =============================================================================
VENV_DIR="/opt/hpc_env"
info "Creating virtual environment at ${VENV_DIR}..."
python3 -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"

pip install --upgrade pip setuptools wheel

# =============================================================================
# 3. TensorFlow
# =============================================================================
info "Installing TensorFlow..."

# Detect CUDA availability and pick the right wheel
if command -v nvcc &>/dev/null || [ -d /usr/local/cuda ]; then
    CUDA_VER=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    info "CUDA detected (${CUDA_VER}) — installing tensorflow[and-cuda]"
    pip install "tensorflow[and-cuda]"
else
    warn "No CUDA detected — installing CPU-only TensorFlow"
    pip install tensorflow
fi

# Quick smoke test
python3 - <<'EOF'
import tensorflow as tf
print(f"  TensorFlow {tf.__version__} — GPUs visible: {tf.config.list_physical_devices('GPU')}")
EOF

# =============================================================================
# 4. mpi4py
# =============================================================================
info "Installing mpi4py (linked against system OpenMPI)..."
MPICC=$(which mpicc) pip install mpi4py

# Quick smoke test
python3 - <<'EOF'
from mpi4py import MPI
print(f"  mpi4py {MPI.Get_version()} — MPI implementation: {MPI.get_vendor()}")
EOF

# =============================================================================
# 5. RDKit
# =============================================================================
info "Installing RDKit..."
pip install rdkit

# Quick smoke test
python3 - <<'EOF'
from rdkit import Chem, rdBase
mol = Chem.MolFromSmiles("CCO")  # Ethanol
print(f"  RDKit {rdBase.rdkitVersion} — test molecule atoms: {mol.GetNumAtoms()}")
EOF

# =============================================================================
# 6. Summary
# =============================================================================
info "All packages installed successfully."
echo ""
echo "=================================================="
echo "  Virtual env : ${VENV_DIR}"
echo "  Activate    : source ${VENV_DIR}/bin/activate"
echo "=================================================="
echo ""
info "Package versions:"
pip show tensorflow mpi4py rdkit 2>/dev/null \
    | grep -E "^(Name|Version):" \
    | paste - - \
    | awk '{printf "  %-12s %s\n", $2, $4}'

deactivate
info "Done. Activate the environment and start coding!"

