#!/bin/bash
#SBATCH --job-name=vp_download
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=48:00:00
#SBATCH --output=/workspace/hraxxg/Vp_global_library/logs/download_run_%j.log

set -euo pipefail

PROJECT_DIR="/workspace/hraxxg/Vp_global_library"
CONDA_SH="/software/miniforge/24.1.2/etc/profile.d/conda.sh"
CONDA_ENV="/workspace/hraxxg/conda-envs/datasets"
BATCH_SIZE="${BATCH_SIZE:-500}"

source "${CONDA_SH}"
conda activate "${CONDA_ENV}"

which datasets || { echo "ERROR: datasets not found"; exit 1; }
datasets --version

mkdir -p "${PROJECT_DIR}/data/raw/ncbi_assembly_packages" \
         "${PROJECT_DIR}/data/raw/ncbi_assemblies" \
         "${PROJECT_DIR}/data/raw/ncbi_assemblies_flat" \
         "${PROJECT_DIR}/logs" \
         "${PROJECT_DIR}/results/accession_lists" \
         "${PROJECT_DIR}/results/summary"

bash "${PROJECT_DIR}/scripts/05_download_ncbi_assemblies.sh" --run --unpack --batch-size "${BATCH_SIZE}"
