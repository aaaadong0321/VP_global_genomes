#!/bin/bash
#SBATCH --job-name=vp_ncbi_dl
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=48:00:00
#SBATCH --output=/workspace/hraxxg/Vp_global_library/logs/download_%j.log

set -euo pipefail

PROJECT_DIR="/workspace/hraxxg/Vp_global_library"
CONDA_SH="/software/miniforge/24.1.2/etc/profile.d/conda.sh"
CONDA_ENV="/workspace/hraxxg/conda-envs/datasets"

# MODE=test downloads a small real test set. MODE=full downloads all remaining
# accessions. Already downloaded FASTA files are detected and skipped.
MODE="${MODE:-test}"
TEST_ACCESSIONS="${TEST_ACCESSIONS:-10}"
BATCH_SIZE="${BATCH_SIZE:-500}"

BACKGROUND_TSV="${PROJECT_DIR}/data/processed/04_biosample_deduplicated.tsv"
PRE2019_ST50_TSV="${PROJECT_DIR}/results/accession_lists/pre_2019_st50_accessions.tsv"
EXTRA_ST50_TSV="${PROJECT_DIR}/results/accession_lists/esr_nz_st50_accessions_checked.tsv"

ACCESSION_DIR="${PROJECT_DIR}/results/accession_lists"
DOWNLOAD_INPUT_DIR="${ACCESSION_DIR}/download_inputs"
BATCH_DIR="${ACCESSION_DIR}/download_batches"
SUMMARY_DIR="${PROJECT_DIR}/results/summary"
LOG_DIR="${PROJECT_DIR}/logs"
PACKAGE_DIR="${PROJECT_DIR}/data/raw/ncbi_assembly_packages"
UNPACK_DIR="${PROJECT_DIR}/data/raw/ncbi_assemblies"
FLAT_FASTA_DIR="${PROJECT_DIR}/data/raw/ncbi_assemblies_flat"

BACKGROUND_ACCESSIONS="${ACCESSION_DIR}/ncbi_2019_background_accessions.txt"
PRE2019_ST50_ACCESSIONS="${ACCESSION_DIR}/pre_2019_st50_download_accessions.txt"
EXTRA_ST50_ACCESSIONS="${ACCESSION_DIR}/extra_st50_download_accessions.txt"
ALL_NCBI_ACCESSIONS="${ACCESSION_DIR}/ncbi_download_accessions_all.txt"

BACKGROUND_TO_DOWNLOAD="${DOWNLOAD_INPUT_DIR}/ncbi_2019_background_accessions_to_download.txt"
PRE2019_TO_DOWNLOAD="${DOWNLOAD_INPUT_DIR}/pre_2019_st50_accessions_to_download.txt"
EXTRA_TO_DOWNLOAD="${DOWNLOAD_INPUT_DIR}/extra_st50_accessions_to_download.txt"
ALL_TO_DOWNLOAD="${DOWNLOAD_INPUT_DIR}/ncbi_accessions_to_download_all.txt"
DOWNLOADED_ACCESSIONS="${ACCESSION_DIR}/downloaded_accessions_existing.txt"

COMMAND_FILE="${LOG_DIR}/06_download_ncbi_assemblies_commands.txt"
RUN_LOG="${LOG_DIR}/06_download_ncbi_assemblies.log"
SUMMARY_FILE="${SUMMARY_DIR}/06_download_ncbi_assemblies_plan.txt"

mkdir -p "${ACCESSION_DIR}" "${DOWNLOAD_INPUT_DIR}" "${BATCH_DIR}" \
         "${SUMMARY_DIR}" "${LOG_DIR}" "${PACKAGE_DIR}" \
         "${UNPACK_DIR}" "${FLAT_FASTA_DIR}"

exec > >(tee -a "${RUN_LOG}") 2>&1
: > "${COMMAND_FILE}"

log() {
  printf '%s\n' "$*"
}

record_command() {
  printf '%s\n' "$*" >> "${COMMAND_FILE}"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "ERROR: required command not found: $1"
    exit 1
  fi
}

extract_accessions() {
  local input="$1"
  local output="$2"
  local label="$3"

  : > "${output}"
  if [[ ! -s "${input}" ]]; then
    log "Skipping ${label}: input not found or empty: ${input}"
    return 0
  fi

  awk -F '\t' '
    BEGIN { col = 0 }
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        h = tolower($i)
        gsub(/[^a-z0-9]+/, "_", h)
        if (h == "assembly_accession" || h == "assembly_accession_version" || h == "accession" || h == "current_accession") {
          col = i
        }
      }
      if (col == 0 && $1 ~ /^(GCA|GCF)_[0-9]+\.[0-9]+$/) {
        print $1
      }
      next
    }
    {
      if (col > 0) {
        v = $col
      } else {
        v = $1
      }
      gsub(/\r/, "", v)
      if (v ~ /^(GCA|GCF)_[0-9]+\.[0-9]+$/) {
        print v
      }
    }
  ' "${input}" | sort -u > "${output}"

  log "${label}: $(wc -l < "${output}" | tr -d ' ') accession(s)"
}

scan_downloaded_accessions() {
  local output="$1"

  : > "${output}"
  if [[ ! -d "${UNPACK_DIR}" ]]; then
    return 0
  fi

  find "${UNPACK_DIR}" -type f \( -name "*.fna" -o -name "*.fna.gz" \) | while IFS= read -r fasta; do
    parent="$(basename "$(dirname "${fasta}")")"
    base="$(basename "${fasta}")"
    acc=""
    if [[ "${parent}" =~ ^(GCA|GCF)_[0-9]+\.[0-9]+$ ]]; then
      acc="${parent}"
    elif [[ "${base}" =~ ^((GCA|GCF)_[0-9]+\.[0-9]+) ]]; then
      acc="${BASH_REMATCH[1]}"
    fi
    if [[ -n "${acc}" ]]; then
      printf '%s\n' "${acc}"
    fi
  done | sort -u > "${output}"

  log "Already downloaded FASTA accessions: $(wc -l < "${output}" | tr -d ' ')"
}

prepare_to_download() {
  local full_list="$1"
  local output="$2"
  local label="$3"

  : > "${output}"
  if [[ ! -s "${full_list}" ]]; then
    log "${label}: full accession list empty"
    return 0
  fi

  tmp="${output}.tmp"
  if [[ -s "${DOWNLOADED_ACCESSIONS}" ]]; then
    awk 'NR == FNR { seen[$1] = 1; next } !($1 in seen)' "${DOWNLOADED_ACCESSIONS}" "${full_list}" > "${tmp}"
  else
    awk 'NF { print $1 }' "${full_list}" > "${tmp}"
  fi

  pending="$(wc -l < "${tmp}" | tr -d ' ')"
  total="$(wc -l < "${full_list}" | tr -d ' ')"
  skipped="$((total - pending))"

  if [[ "${MODE}" == "test" ]]; then
    head -n "${TEST_ACCESSIONS}" "${tmp}" > "${output}"
  else
    mv "${tmp}" "${output}"
  fi
  rm -f "${tmp}"

  selected="$(wc -l < "${output}" | tr -d ' ')"
  log "${label}: total=${total}, already_downloaded=${skipped}, pending=${pending}, selected_this_run=${selected}"
}

download_and_rehydrate_batches() {
  local label="$1"
  local accession_file="$2"
  local package_prefix="$3"
  local unpack_prefix="$4"

  count="$(wc -l < "${accession_file}" | tr -d ' ')"
  if [[ "${count}" == "0" ]]; then
    log "Skipping ${label}: no accessions selected"
    return 0
  fi

  label_slug="$(basename "${package_prefix}")"
  batch_dir="${BATCH_DIR}/${label_slug}"
  rm -rf "${batch_dir}"
  mkdir -p "${batch_dir}"

  awk -v n="${BATCH_SIZE}" -v out_dir="${batch_dir}" '
    NF {
      batch = int((NR - 1) / n) + 1
      file = sprintf("%s/batch_%03d.txt", out_dir, batch)
      print $0 > file
    }
  ' "${accession_file}"

  for batch_file in "${batch_dir}"/batch_*.txt; do
    [[ -s "${batch_file}" ]] || continue
    batch_name="$(basename "${batch_file%.txt}")"
    zip_file="${package_prefix}_${batch_name}.zip"
    out_dir="${unpack_prefix}/${batch_name}"
    batch_count="$(wc -l < "${batch_file}" | tr -d ' ')"

    log "=== ${label} ${batch_name}: ${batch_count} accession(s) ==="

    cmd="datasets download genome accession --inputfile \"${batch_file}\" --include genome --dehydrated --filename \"${zip_file}\" --no-progressbar"
    record_command "${cmd}"

    if [[ -s "${zip_file}" ]] && unzip -tq "${zip_file}" >/dev/null 2>&1; then
      log "Using existing valid ZIP: ${zip_file}"
    else
      rm -f "${zip_file}"
      datasets download genome accession \
        --inputfile "${batch_file}" \
        --include genome \
        --dehydrated \
        --filename "${zip_file}" \
        --no-progressbar
    fi

    mkdir -p "${out_dir}"
    unzip -q -o "${zip_file}" -d "${out_dir}"

    cmd="datasets rehydrate --directory \"${out_dir}\" --no-progressbar"
    record_command "${cmd}"
    datasets rehydrate --directory "${out_dir}" --no-progressbar
  done
}

flatten_fastas() {
  local label="$1"
  local search_dir="$2"
  local flat_dir="$3"
  local manifest="$4"

  mkdir -p "${flat_dir}"
  : > "${manifest}"
  if [[ ! -d "${search_dir}" ]]; then
    log "No directory to flatten for ${label}: ${search_dir}"
    return 0
  fi

  find "${search_dir}" -type f \( -name "*.fna" -o -name "*.fna.gz" \) | sort | while IFS= read -r fasta; do
    parent="$(basename "$(dirname "${fasta}")")"
    base="$(basename "${fasta}")"
    acc="${parent}"
    if [[ ! "${acc}" =~ ^(GCA|GCF)_[0-9]+\.[0-9]+$ && "${base}" =~ ^((GCA|GCF)_[0-9]+\.[0-9]+) ]]; then
      acc="${BASH_REMATCH[1]}"
    fi
    link="${flat_dir}/${acc}_${base}"
    ln -sf "${fasta}" "${link}"
    printf '%s\t%s\t%s\n' "${acc}" "${fasta}" "${link}" >> "${manifest}"
  done

  log "${label} flat FASTA manifest: ${manifest}"
}

validate_selected() {
  local label="$1"
  local selected_file="$2"

  selected="$(wc -l < "${selected_file}" | tr -d ' ')"
  if [[ "${selected}" == "0" ]]; then
    log "Validation ${label}: selected=0"
    return 0
  fi

  present="$(awk 'NR == FNR { got[$1] = 1; next } ($1 in got) { n++ } END { print n + 0 }' "${DOWNLOADED_ACCESSIONS}" "${selected_file}")"
  log "Validation ${label}: downloaded ${present}/${selected} selected accession(s)"
  if [[ "${present}" -lt "${selected}" ]]; then
    log "WARNING ${label}: $((selected - present)) selected accession(s) not found as FASTA after rehydration"
  fi
}

if [[ "${MODE}" != "test" && "${MODE}" != "full" ]]; then
  log "ERROR: MODE must be test or full"
  exit 2
fi

source "${CONDA_SH}"
conda activate "${CONDA_ENV}"

require_command datasets
require_command awk
require_command find
require_command sort
require_command unzip
require_command wc

log "Run date: $(date -Is)"
log "Host: $(hostname)"
log "SLURM_JOB_ID: ${SLURM_JOB_ID:-NA}"
log "Project directory: ${PROJECT_DIR}"
log "Mode: ${MODE}"
log "Test accessions: ${TEST_ACCESSIONS}"
log "Batch size: ${BATCH_SIZE}"
log "datasets version: $(datasets --version 2>/dev/null || echo unknown)"
log ""

extract_accessions "${BACKGROUND_TSV}" "${BACKGROUND_ACCESSIONS}" "NCBI 2019+ background pool"
extract_accessions "${PRE2019_ST50_TSV}" "${PRE2019_ST50_ACCESSIONS}" "Pre-2019 ST50 supplement"
extract_accessions "${EXTRA_ST50_TSV}" "${EXTRA_ST50_ACCESSIONS}" "Extra ESR/NZ ST50 supplement"
cat "${BACKGROUND_ACCESSIONS}" "${PRE2019_ST50_ACCESSIONS}" "${EXTRA_ST50_ACCESSIONS}" | sort -u > "${ALL_NCBI_ACCESSIONS}"
log "All NCBI full accession list: $(wc -l < "${ALL_NCBI_ACCESSIONS}" | tr -d ' ')"
log ""

scan_downloaded_accessions "${DOWNLOADED_ACCESSIONS}"
prepare_to_download "${BACKGROUND_ACCESSIONS}" "${BACKGROUND_TO_DOWNLOAD}" "NCBI 2019+ background pool"
prepare_to_download "${PRE2019_ST50_ACCESSIONS}" "${PRE2019_TO_DOWNLOAD}" "Pre-2019 ST50 supplement"
prepare_to_download "${EXTRA_ST50_ACCESSIONS}" "${EXTRA_TO_DOWNLOAD}" "Extra ESR/NZ ST50 supplement"
cat "${BACKGROUND_TO_DOWNLOAD}" "${PRE2019_TO_DOWNLOAD}" "${EXTRA_TO_DOWNLOAD}" | sort -u > "${ALL_TO_DOWNLOAD}"
log "All selected for this run: $(wc -l < "${ALL_TO_DOWNLOAD}" | tr -d ' ')"
log ""

run_suffix=""
if [[ "${MODE}" == "test" ]]; then
  run_suffix="_test_${TEST_ACCESSIONS}"
fi

download_and_rehydrate_batches \
  "NCBI 2019+ background pool" \
  "${BACKGROUND_TO_DOWNLOAD}" \
  "${PACKAGE_DIR}/ncbi_2019_background_genomes${run_suffix}" \
  "${UNPACK_DIR}/ncbi_2019_background"

download_and_rehydrate_batches \
  "Pre-2019 ST50 supplement" \
  "${PRE2019_TO_DOWNLOAD}" \
  "${PACKAGE_DIR}/pre_2019_st50_genomes${run_suffix}" \
  "${UNPACK_DIR}/pre_2019_st50"

download_and_rehydrate_batches \
  "Extra ESR/NZ ST50 supplement" \
  "${EXTRA_TO_DOWNLOAD}" \
  "${PACKAGE_DIR}/extra_st50_genomes${run_suffix}" \
  "${UNPACK_DIR}/extra_st50"

scan_downloaded_accessions "${DOWNLOADED_ACCESSIONS}"
validate_selected "NCBI 2019+ background pool" "${BACKGROUND_TO_DOWNLOAD}"
validate_selected "Pre-2019 ST50 supplement" "${PRE2019_TO_DOWNLOAD}"
validate_selected "Extra ESR/NZ ST50 supplement" "${EXTRA_TO_DOWNLOAD}"
validate_selected "All NCBI selected this run" "${ALL_TO_DOWNLOAD}"

flatten_fastas \
  "NCBI 2019+ background pool" \
  "${UNPACK_DIR}/ncbi_2019_background" \
  "${FLAT_FASTA_DIR}/ncbi_2019_background" \
  "${ACCESSION_DIR}/ncbi_2019_background_fasta_manifest.tsv"

flatten_fastas \
  "Pre-2019 ST50 supplement" \
  "${UNPACK_DIR}/pre_2019_st50" \
  "${FLAT_FASTA_DIR}/pre_2019_st50" \
  "${ACCESSION_DIR}/pre_2019_st50_fasta_manifest.tsv"

flatten_fastas \
  "Extra ESR/NZ ST50 supplement" \
  "${UNPACK_DIR}/extra_st50" \
  "${FLAT_FASTA_DIR}/extra_st50" \
  "${ACCESSION_DIR}/extra_st50_fasta_manifest.tsv"

{
  echo "NCBI assembly download summary"
  echo
  echo "Run date: $(date -Is)"
  echo "SLURM_JOB_ID: ${SLURM_JOB_ID:-NA}"
  echo "Mode: ${MODE}"
  echo "Test accessions: ${TEST_ACCESSIONS}"
  echo "Batch size: ${BATCH_SIZE}"
  echo "datasets version: $(datasets --version 2>/dev/null || echo unknown)"
  echo
  echo "| Dataset | Full accession list | Full count | This-run accession list | This-run count | Unpack directory | Flat FASTA directory |"
  echo "|---|---|---:|---|---:|---|---|"
  echo "| NCBI 2019+ background pool | ${BACKGROUND_ACCESSIONS} | $(wc -l < "${BACKGROUND_ACCESSIONS}" | tr -d ' ') | ${BACKGROUND_TO_DOWNLOAD} | $(wc -l < "${BACKGROUND_TO_DOWNLOAD}" | tr -d ' ') | ${UNPACK_DIR}/ncbi_2019_background | ${FLAT_FASTA_DIR}/ncbi_2019_background |"
  echo "| Pre-2019 ST50 supplement | ${PRE2019_ST50_ACCESSIONS} | $(wc -l < "${PRE2019_ST50_ACCESSIONS}" | tr -d ' ') | ${PRE2019_TO_DOWNLOAD} | $(wc -l < "${PRE2019_TO_DOWNLOAD}" | tr -d ' ') | ${UNPACK_DIR}/pre_2019_st50 | ${FLAT_FASTA_DIR}/pre_2019_st50 |"
  echo "| Extra ESR/NZ ST50 supplement | ${EXTRA_ST50_ACCESSIONS} | $(wc -l < "${EXTRA_ST50_ACCESSIONS}" | tr -d ' ') | ${EXTRA_TO_DOWNLOAD} | $(wc -l < "${EXTRA_TO_DOWNLOAD}" | tr -d ' ') | ${UNPACK_DIR}/extra_st50 | ${FLAT_FASTA_DIR}/extra_st50 |"
  echo "| All NCBI accessions | ${ALL_NCBI_ACCESSIONS} | $(wc -l < "${ALL_NCBI_ACCESSIONS}" | tr -d ' ') | ${ALL_TO_DOWNLOAD} | $(wc -l < "${ALL_TO_DOWNLOAD}" | tr -d ' ') | ${UNPACK_DIR} | ${FLAT_FASTA_DIR} |"
  echo
  echo "Already downloaded accession scan: ${DOWNLOADED_ACCESSIONS}"
  echo "Exact NCBI commands: ${COMMAND_FILE}"
  echo "Run log: ${RUN_LOG}"
} > "${SUMMARY_FILE}"

log ""
log "Wrote summary: ${SUMMARY_FILE}"
log "Wrote exact command record: ${COMMAND_FILE}"
log "Done."
