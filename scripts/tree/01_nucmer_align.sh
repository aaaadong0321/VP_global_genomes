#!/usr/bin/env bash
set -euo pipefail
# 01_nucmer_align.sh <task_id> -- align genome (genome_list.txt line N) to RIMD
module load MUMmer/4.0.0rc1 2>/dev/null || true
P=/workspace/hraxxg/Vp_global_library
REF=$P/data/reference/RIMD2210633_GCF_000196095.1.fna
TI=$P/data/tree_input_v2
LIST=$TI/genome_list.txt
OUT=$P/results/nucmer
mkdir -p "$OUT"
i=$(( $1 + ${2:-0} ))
GID=$(sed -n "${i}p" "$LIST")
if [ -z "$GID" ]; then echo "ERROR: no genome at line $i"; exit 1; fi
FNA=$TI/$GID.fna
if [ ! -s "$FNA" ]; then echo "ERROR: missing $FNA"; exit 1; fi
if [ -f "$OUT/$GID.done" ]; then echo "[$i] $GID done, skip"; exit 0; fi
if ! command -v nucmer >/dev/null; then echo "ERROR: nucmer not found (module?)"; exit 1; fi
cd "$OUT"
nucmer --prefix="$GID" "$REF" "$FNA"
delta-filter -1 "$GID.delta" > "$GID.filter.delta"
show-snps -H -C -T "$GID.filter.delta" > "$GID.snps"
show-coords -H -r -c -l -T "$GID.filter.delta" > "$GID.coords"
rm -f "$GID.delta" "$GID.filter.delta"
touch "$OUT/$GID.done"
echo "[$i] $GID done: $(wc -l < "$GID.snps") snp-lines"
