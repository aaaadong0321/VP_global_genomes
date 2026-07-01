#!/usr/bin/env bash
set -euo pipefail
module load conda/24.1.2
P=/workspace/hraxxg/Vp_global_library
IN=$P/results/core_snp/core_snps.t99.fasta
OUT=$P/results/core_snp/core_snps.t99.snpsites.fasta
conda run -p /workspace/hraxxg/conda-envs/snippy snp-sites -o "$OUT" "$IN"
echo "DONE -> $OUT"; grep -c '^>' "$OUT"
