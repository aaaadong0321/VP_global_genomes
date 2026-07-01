#!/usr/bin/env bash
set -euo pipefail
P=/workspace/hraxxg/Vp_global_library
IN=$P/results/core_snp/core_snps.t99.snpsites.fasta
OUT=$P/results/tree/global_t99.double.fasttree.nwk
LOG=$P/results/tree/global_t99.double.fastlog
mkdir -p "$(dirname "$OUT")"
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-8}
FT=/workspace/appscratch/miniforge/fasttreemp/bin/FastTreeMP

[ -s "$IN" ] || { echo "ERROR: missing/empty input $IN"; exit 1; }
[ -x "$FT" ] || { echo "ERROR: FastTreeMP not executable $FT"; exit 1; }

echo "using $FT  threads=$OMP_NUM_THREADS"
"$FT" < /dev/null 2>&1 | head -1 || true        # 记录 banner(版本/精度/线程)

"$FT" -nt -gtr -gamma -log "$LOG" "$IN" > "$OUT"
echo "DONE -> $OUT"
