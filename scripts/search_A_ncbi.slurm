#!/bin/bash
#SBATCH --job-name=search_A
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=01:00:00
#SBATCH --output=/workspace/hraxxg/Vp_global_library/logs/search_A_%j.log

source /software/miniforge/24.1.2/etc/profile.d/conda.sh
conda activate /workspace/hraxxg/conda-envs/datasets

NAMES="/workspace/hraxxg/Vp_global_library/results/data_integration/a_unique_names.txt"
OUT="/workspace/hraxxg/Vp_global_library/results/data_integration/A_ncbi_info.tsv"
echo -e "A_number\tGCA\tBioSample\tST\tcollection_date\tassembly_status" > "$OUT"

while read aname; do
    [[ -z "$aname" ]] && continue
    json=$(datasets summary genome taxon "Vibrio parahaemolyticus" --search "$aname" 2>/dev/null)
    if [[ -n "$json" ]]; then
        echo "$json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d['reports'][0]
    gca = r.get('accession','')
    ai = r.get('assembly_info',{})
    status = ai.get('assembly_status','')
    bs_obj = ai.get('biosample',{})
    bs = bs_obj.get('accession','')
    attrs = {a['name']:a['value'] for a in bs_obj.get('attributes',[])}
    st = attrs.get('genotype','').replace('ST ','').replace('ST','').strip()
    cdate = attrs.get('collection_date','')
    print(f'${aname}\t{gca}\t{bs}\t{st}\t{cdate}\t{status}')
except Exception as e:
    print(f'${aname}\t\t\t\t\tERROR')
" >> "$OUT"
        echo "DONE: $aname"
    else
        echo -e "${aname}\t\t\t\t\tNOT_FOUND" >> "$OUT"
        echo "NOT_FOUND: $aname"
    fi
done < "$NAMES"

echo "=== 统计 ==="
echo "总数: $(($(wc -l < "$OUT") - 1))"
echo "有GCA: $(tail -n +2 "$OUT" | awk -F'\t' '\$2!="" {n++} END{print n+0}')"
echo "suppressed: $(tail -n +2 "$OUT" | awk -F'\t' '\$6=="suppressed" {n++} END{print n+0}')"
