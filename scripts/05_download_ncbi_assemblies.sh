#!/usr/bin/env bash
set -euo pipefail

# Download NCBI genome assemblies for the current public background pool and
# optional ST50 supplement accession lists.
#
# Default mode is dry-run: generate accession lists and command records, but do
# not download large genome packages unless --run is supplied. Genome packages
# use NCBI Datasets dehydrated mode by default so large downloads can be
# rehydrated/resumed more safely than a single direct ZIP download. Large
# accession lists are split into batches by default to avoid one oversized NCBI
# Datasets request.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BACKGROUND_TSV="${PROJECT_DIR}/data/processed/04_biosample_deduplicated.tsv"
PRE2019_ST50_TSV="${PROJECT_DIR}/results/accession_lists/pre_2019_st50_accessions.tsv"
EXTRA_ST50_TSV="${PROJECT_DIR}/results/accession_lists/esr_nz_st50_accessions_checked.tsv"

ACCESSION_DIR="${PROJECT_DIR}/results/accession_lists"
SUMMARY_DIR="${PROJECT_DIR}/results/summary"
LOG_DIR="${PROJECT_DIR}/logs"
PACKAGE_DIR="${PROJECT_DIR}/data/raw/ncbi_assembly_packages"
UNPACK_DIR="${PROJECT_DIR}/data/raw/ncbi_assemblies"
FLAT_FASTA_DIR="${PROJECT_DIR}/data/raw/ncbi_assemblies_flat"
BATCH_DIR="${ACCESSION_DIR}/download_batches"

BACKGROUND_ACCESSIONS="${ACCESSION_DIR}/ncbi_2019_background_accessions.txt"
PRE2019_ST50_ACCESSIONS="${ACCESSION_DIR}/pre_2019_st50_download_accessions.txt"
EXTRA_ST50_ACCESSIONS="${ACCESSION_DIR}/extra_st50_download_accessions.txt"
ALL_NCBI_ACCESSIONS="${ACCESSION_DIR}/ncbi_download_accessions_all.txt"

BACKGROUND_ZIP="${PACKAGE_DIR}/ncbi_2019_background_genomes.zip"
PRE2019_ST50_ZIP="${PACKAGE_DIR}/pre_2019_st50_genomes.zip"
EXTRA_ST50_ZIP="${PACKAGE_DIR}/extra_st50_genomes.zip"

LOG_FILE="${LOG_DIR}/06_download_ncbi_assemblies.log"
COMMAND_FILE="${LOG_DIR}/06_download_ncbi_assemblies_commands.txt"
SUMMARY_FILE="${SUMMARY_DIR}/06_download_ncbi_assemblies_plan.txt"

RUN_DOWNLOAD=0
UNPACK=0
DEHYDRATED=1
FLATTEN=0
BATCH_SIZE=500

usage() {
  cat <<EOF
Usage: $(basename "$0") [--run] [--unpack] [--flatten] [--direct] [--batch-size N] [--no-batch]

Default: dry-run only. The script creates accession lists and records the exact
datasets commands that would be used, but does not download genome FASTA files.

Options:
  --run       Actually run NCBI Datasets downloads.
  --unpack    After downloads, unpack ZIPs, rehydrate dehydrated packages,
              validate FASTA counts, and create flat FASTA symlinks.
  --flatten   Create/update flat FASTA symlinks from already unpacked data.
  --direct    Use direct genome ZIP downloads instead of dehydrated mode.
  --batch-size N
              Split accession lists into batches of N before downloading.
              Default: ${BATCH_SIZE}.
  --no-batch  Download each accession list as a single NCBI Datasets request.
  -h, --help  Show this help message.

Inputs:
  ${BACKGROUND_TSV}
  ${PRE2019_ST50_TSV} (optional)
  ${EXTRA_ST50_TSV} (optional)

Outputs:
  ${BACKGROUND_ACCESSIONS}
  ${PRE2019_ST50_ACCESSIONS}
  ${EXTRA_ST50_ACCESSIONS}
  ${ALL_NCBI_ACCESSIONS}
  ${COMMAND_FILE}
  ${SUMMARY_FILE}
  ${LOG_FILE}
  ${FLAT_FASTA_DIR}/
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run)
      RUN_DOWNLOAD=1
      shift
      ;;
    --unpack)
      UNPACK=1
      FLATTEN=1
      shift
      ;;
    --flatten)
      FLATTEN=1
      shift
      ;;
    --direct)
      DEHYDRATED=0
      shift
      ;;
    --batch-size)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" == "0" ]]; then
        echo "ERROR: --batch-size requires a positive integer" >&2
        exit 2
      fi
      BATCH_SIZE="$2"
      shift 2
      ;;
    --no-batch)
      BATCH_SIZE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "${ACCESSION_DIR}" "${SUMMARY_DIR}" "${LOG_DIR}" "${PACKAGE_DIR}" "${UNPACK_DIR}" "${BATCH_DIR}"
: > "${LOG_FILE}"
: > "${COMMAND_FILE}"
: > "${SUMMARY_FILE}"

log() {
  printf '%s\n' "$*" | tee -a "${LOG_FILE}"
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

  local count
  count="$(wc -l < "${output}" | tr -d ' ')"
  log "${label}: wrote ${count} assembly accession(s) to ${output}"
}

batch_dir_for_zip() {
  local zip_file="$1"
  local base
  base="$(basename "${zip_file%.zip}")"
  printf '%s/%s\n' "${BATCH_DIR}" "${base}"
}

batch_zip_for_file() {
  local zip_file="$1"
  local batch_file="$2"
  local batch_name
  batch_name="$(basename "${batch_file%.txt}")"
  printf '%s_%s.zip\n' "${zip_file%.zip}" "${batch_name}"
}

split_accessions() {
  local accession_file="$1"
  local zip_file="$2"
  local count="$3"

  local batch_dir
  batch_dir="$(batch_dir_for_zip "${zip_file}")"
  rm -rf "${batch_dir}"
  mkdir -p "${batch_dir}"

  awk -v n="${BATCH_SIZE}" -v out_dir="${batch_dir}" '
    NF {
      batch = int((NR - 1) / n) + 1
      file = sprintf("%s/batch_%03d.txt", out_dir, batch)
      print $0 > file
    }
  ' "${accession_file}"

  local batch_count
  batch_count="$(find "${batch_dir}" -type f -name 'batch_*.txt' | wc -l | tr -d ' ')"
  log "Split ${count} accession(s) into ${batch_count} batch file(s): ${batch_dir}"
}

run_datasets_download() {
  local label="$1"
  local accession_file="$2"
  local zip_file="$3"

  local count
  count="$(wc -l < "${accession_file}" | tr -d ' ')"

  local cmd
  if [[ "${DEHYDRATED}" == "1" ]]; then
    cmd="datasets download genome accession --inputfile \"${accession_file}\" --include genome --dehydrated --filename \"${zip_file}\" --no-progressbar"
  else
    cmd="datasets download genome accession --inputfile \"${accession_file}\" --include genome --filename \"${zip_file}\" --no-progressbar"
  fi
  record_command "${cmd}"

  if [[ "${RUN_DOWNLOAD}" == "1" ]]; then
    if [[ -s "${zip_file}" ]]; then
      log "Skipping existing package for ${label}: ${zip_file}"
      return 0
    fi
    log "Downloading ${label}: ${count} accession(s)"
    if [[ "${DEHYDRATED}" == "1" ]]; then
      datasets download genome accession --inputfile "${accession_file}" --include genome --dehydrated --filename "${zip_file}" --no-progressbar 2>&1 | tee -a "${LOG_FILE}"
    else
      datasets download genome accession --inputfile "${accession_file}" --include genome --filename "${zip_file}" --no-progressbar 2>&1 | tee -a "${LOG_FILE}"
    fi
  else
    if [[ "${DEHYDRATED}" == "1" ]]; then
      log "Dry-run ${label}: would download dehydrated package for ${count} accession(s) to ${zip_file}"
    else
      log "Dry-run ${label}: would download direct genome package for ${count} accession(s) to ${zip_file}"
    fi
  fi
}

download_package() {
  local label="$1"
  local accession_file="$2"
  local zip_file="$3"

  local count
  count="$(wc -l < "${accession_file}" | tr -d ' ')"
  if [[ "${count}" == "0" ]]; then
    log "Skipping ${label}: no assembly accessions."
    return 0
  fi

  if [[ "${BATCH_SIZE}" -gt 0 && "${count}" -gt "${BATCH_SIZE}" ]]; then
    split_accessions "${accession_file}" "${zip_file}" "${count}"
    local batch_file
    for batch_file in "$(batch_dir_for_zip "${zip_file}")"/batch_*.txt; do
      [[ -s "${batch_file}" ]] || continue
      local batch_zip
      local batch_name
      batch_zip="$(batch_zip_for_file "${zip_file}" "${batch_file}")"
      batch_name="$(basename "${batch_file%.txt}")"
      run_datasets_download "${label} ${batch_name}" "${batch_file}" "${batch_zip}"
    done
  else
    run_datasets_download "${label}" "${accession_file}" "${zip_file}"
  fi
}

unpack_one_package() {
  local label="$1"
  local zip_file="$2"
  local out_dir="$3"

  if [[ ! -s "${zip_file}" ]]; then
    log "Skipping unpack for ${label}: ZIP not found: ${zip_file}"
    return 0
  fi

  mkdir -p "${out_dir}"
  log "Unpacking ${label} to ${out_dir}"
  unzip -q -o "${zip_file}" -d "${out_dir}"

  if [[ "${DEHYDRATED}" == "1" ]]; then
    local cmd
    cmd="datasets rehydrate --directory \"${out_dir}\" --no-progressbar"
    record_command "${cmd}"
    log "Rehydrating ${label} in ${out_dir}"
    datasets rehydrate --directory "${out_dir}" --no-progressbar 2>&1 | tee -a "${LOG_FILE}"
  fi
}

unpack_package() {
  local label="$1"
  local zip_file="$2"
  local out_dir="$3"

  local found_batch=0
  local batch_zip
  for batch_zip in "${zip_file%.zip}"_batch_*.zip; do
    [[ -s "${batch_zip}" ]] || continue
    found_batch=1
    local batch_name
    batch_name="$(basename "${batch_zip%.zip}")"
    unpack_one_package "${label} ${batch_name}" "${batch_zip}" "${out_dir}/${batch_name}"
  done

  if [[ "${found_batch}" == "0" ]]; then
    unpack_one_package "${label}" "${zip_file}" "${out_dir}"
  fi
}

count_fastas() {
  local search_dir="$1"

  if [[ ! -d "${search_dir}" ]]; then
    echo "0"
    return 0
  fi

  find "${search_dir}" -type f \( -name "*.fna" -o -name "*.fna.gz" \) | wc -l | tr -d ' '
}

validate_download() {
  local label="$1"
  local accession_file="$2"
  local search_dir="$3"

  local expected
  expected="$(wc -l < "${accession_file}" | tr -d ' ')"
  if [[ "${expected}" == "0" ]]; then
    log "Validation ${label}: expected 0 assembly FASTA files; skipping."
    return 0
  fi

  if [[ ! -d "${search_dir}" ]]; then
    log "Validation ${label}: unpack directory not found: ${search_dir}"
    return 0
  fi

  local actual
  actual="$(count_fastas "${search_dir}")"
  log "Validation ${label}: expected ${expected} assembly FASTA file(s), found ${actual}"
  if [[ "${actual}" -lt "${expected}" ]]; then
    log "WARNING ${label}: $((expected - actual)) expected assembly FASTA file(s) missing after download/rehydration"
  fi
}

flatten_fastas() {
  local label="$1"
  local search_dir="$2"
  local flat_dir="$3"
  local manifest="$4"

  if [[ ! -d "${search_dir}" ]]; then
    log "Skipping flat FASTA symlinks for ${label}: directory not found: ${search_dir}"
    return 0
  fi

  mkdir -p "${flat_dir}"
  : > "${manifest}"

  local count
  count="$(count_fastas "${search_dir}")"
  if [[ "${count}" == "0" ]]; then
    log "Skipping flat FASTA symlinks for ${label}: no FASTA files found in ${search_dir}"
    return 0
  fi

  log "Creating flat FASTA symlinks for ${label}: ${count} FASTA file(s)"
  while IFS= read -r fasta; do
    local parent
    local base
    local acc
    local link

    parent="$(basename "$(dirname "${fasta}")")"
    base="$(basename "${fasta}")"
    acc="${parent}"
    if [[ ! "${acc}" =~ ^(GCA|GCF)_[0-9]+\.[0-9]+$ && "${base}" =~ ^((GCA|GCF)_[0-9]+\.[0-9]+) ]]; then
      acc="${BASH_REMATCH[1]}"
    fi

    link="${flat_dir}/${acc}_${base}"
    ln -sf "${fasta}" "${link}"
    printf '%s\t%s\t%s\n' "${acc}" "${fasta}" "${link}" >> "${manifest}"
  done < <(find "${search_dir}" -type f \( -name "*.fna" -o -name "*.fna.gz" \) | sort)

  log "Wrote flat FASTA manifest for ${label}: ${manifest}"
}

require_command datasets
require_command awk
require_command find
require_command sort
require_command wc
if [[ "${UNPACK}" == "1" ]]; then
  require_command unzip
fi
if [[ "${UNPACK}" == "1" || "${FLATTEN}" == "1" ]]; then
  require_command ln
fi

log "Project directory: ${PROJECT_DIR}"
log "Run mode: $([[ "${RUN_DOWNLOAD}" == "1" ]] && echo "download" || echo "dry-run")"
log "Download mode: $([[ "${DEHYDRATED}" == "1" ]] && echo "dehydrated" || echo "direct ZIP")"
log "Batch size: $([[ "${BATCH_SIZE}" == "0" ]] && echo "disabled" || echo "${BATCH_SIZE}")"
log "datasets version: $(datasets --version 2>/dev/null || echo 'unknown')"
log ""

extract_accessions "${BACKGROUND_TSV}" "${BACKGROUND_ACCESSIONS}" "NCBI 2019+ background pool"
extract_accessions "${PRE2019_ST50_TSV}" "${PRE2019_ST50_ACCESSIONS}" "Pre-2019 ST50 supplement"
extract_accessions "${EXTRA_ST50_TSV}" "${EXTRA_ST50_ACCESSIONS}" "Extra ESR/NZ ST50 supplement"

cat "${BACKGROUND_ACCESSIONS}" "${PRE2019_ST50_ACCESSIONS}" "${EXTRA_ST50_ACCESSIONS}" | sort -u > "${ALL_NCBI_ACCESSIONS}"
ALL_COUNT="$(wc -l < "${ALL_NCBI_ACCESSIONS}" | tr -d ' ')"
log "All NCBI download accessions: wrote ${ALL_COUNT} unique accession(s) to ${ALL_NCBI_ACCESSIONS}"
log ""

download_package "NCBI 2019+ background pool" "${BACKGROUND_ACCESSIONS}" "${BACKGROUND_ZIP}"
download_package "Pre-2019 ST50 supplement" "${PRE2019_ST50_ACCESSIONS}" "${PRE2019_ST50_ZIP}"
download_package "Extra ESR/NZ ST50 supplement" "${EXTRA_ST50_ACCESSIONS}" "${EXTRA_ST50_ZIP}"

if [[ "${UNPACK}" == "1" ]]; then
  unpack_package "NCBI 2019+ background pool" "${BACKGROUND_ZIP}" "${UNPACK_DIR}/ncbi_2019_background"
  unpack_package "Pre-2019 ST50 supplement" "${PRE2019_ST50_ZIP}" "${UNPACK_DIR}/pre_2019_st50"
  unpack_package "Extra ESR/NZ ST50 supplement" "${EXTRA_ST50_ZIP}" "${UNPACK_DIR}/extra_st50"
fi

if [[ "${UNPACK}" == "1" || "${FLATTEN}" == "1" ]]; then
  validate_download "NCBI 2019+ background pool" "${BACKGROUND_ACCESSIONS}" "${UNPACK_DIR}/ncbi_2019_background"
  validate_download "Pre-2019 ST50 supplement" "${PRE2019_ST50_ACCESSIONS}" "${UNPACK_DIR}/pre_2019_st50"
  validate_download "Extra ESR/NZ ST50 supplement" "${EXTRA_ST50_ACCESSIONS}" "${UNPACK_DIR}/extra_st50"
  validate_download "All NCBI accessions" "${ALL_NCBI_ACCESSIONS}" "${UNPACK_DIR}"

  flatten_fastas "NCBI 2019+ background pool" "${UNPACK_DIR}/ncbi_2019_background" "${FLAT_FASTA_DIR}/ncbi_2019_background" "${ACCESSION_DIR}/ncbi_2019_background_fasta_manifest.tsv"
  flatten_fastas "Pre-2019 ST50 supplement" "${UNPACK_DIR}/pre_2019_st50" "${FLAT_FASTA_DIR}/pre_2019_st50" "${ACCESSION_DIR}/pre_2019_st50_fasta_manifest.tsv"
  flatten_fastas "Extra ESR/NZ ST50 supplement" "${UNPACK_DIR}/extra_st50" "${FLAT_FASTA_DIR}/extra_st50" "${ACCESSION_DIR}/extra_st50_fasta_manifest.tsv"
fi

{
  echo "NCBI assembly download plan"
  echo
  echo "Run mode: $([[ "${RUN_DOWNLOAD}" == "1" ]] && echo "download" || echo "dry-run")"
  echo "Download mode: $([[ "${DEHYDRATED}" == "1" ]] && echo "dehydrated" || echo "direct ZIP")"
  echo "Batch size: $([[ "${BATCH_SIZE}" == "0" ]] && echo "disabled" || echo "${BATCH_SIZE}")"
  echo "datasets version: $(datasets --version 2>/dev/null || echo 'unknown')"
  echo
  echo "| Dataset | Input | Accession list | Count | ZIP output | Unpack directory | Flat FASTA directory |"
  echo "|---|---|---|---:|---|---|---|"
  echo "| NCBI 2019+ background pool | ${BACKGROUND_TSV} | ${BACKGROUND_ACCESSIONS} | $(wc -l < "${BACKGROUND_ACCESSIONS}" | tr -d ' ') | ${BACKGROUND_ZIP} | ${UNPACK_DIR}/ncbi_2019_background | ${FLAT_FASTA_DIR}/ncbi_2019_background |"
  echo "| Pre-2019 ST50 supplement | ${PRE2019_ST50_TSV} | ${PRE2019_ST50_ACCESSIONS} | $(wc -l < "${PRE2019_ST50_ACCESSIONS}" | tr -d ' ') | ${PRE2019_ST50_ZIP} | ${UNPACK_DIR}/pre_2019_st50 | ${FLAT_FASTA_DIR}/pre_2019_st50 |"
  echo "| Extra ESR/NZ ST50 supplement | ${EXTRA_ST50_TSV} | ${EXTRA_ST50_ACCESSIONS} | $(wc -l < "${EXTRA_ST50_ACCESSIONS}" | tr -d ' ') | ${EXTRA_ST50_ZIP} | ${UNPACK_DIR}/extra_st50 | ${FLAT_FASTA_DIR}/extra_st50 |"
  echo "| All NCBI accessions | combined | ${ALL_NCBI_ACCESSIONS} | ${ALL_COUNT} | packages above | ${UNPACK_DIR} | ${FLAT_FASTA_DIR} |"
  echo
  echo "Flat FASTA manifests, when --unpack or --flatten is used:"
  echo "- ${ACCESSION_DIR}/ncbi_2019_background_fasta_manifest.tsv"
  echo "- ${ACCESSION_DIR}/pre_2019_st50_fasta_manifest.tsv"
  echo "- ${ACCESSION_DIR}/extra_st50_fasta_manifest.tsv"
  echo
  echo "Exact commands are recorded in: ${COMMAND_FILE}"
  echo "Run log: ${LOG_FILE}"
} > "${SUMMARY_FILE}"

log ""
log "Wrote command record: ${COMMAND_FILE}"
log "Wrote summary: ${SUMMARY_FILE}"
log "Done."
