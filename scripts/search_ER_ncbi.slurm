#!/bin/bash
#SBATCH --job-name=search_ER
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:30:00
#SBATCH --output=/workspace/hraxxg/Vp_global_library/logs/search_ER_%j.log

source /software/miniforge/24.1.2/etc/profile.d/conda.sh
conda activate /workspace/hraxxg/conda-envs/datasets

NAMES="/workspace/hraxxg/Vp_global_library/results/data_integration/er_nonst50_list.txt"
OUT="/workspace/hraxxg/Vp_global_library/results/data_integration/ER_nonst50_ncbi_info.tsv"
echo -e "ER_number\tGCA\tBioSample\tST\tcollection_date\tassembly_status" > "$OUT"

while read ername; do
    [[ -z "$ername" ]] && continue
    json=$(datasets summary genome taxon "Vibrio parahaemolyticus" --search "$ername" 2>/dev/null)
    if [[ -n "$json" ]]; then
        echo "$json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    reports = d.get('reports',[])
    if not reports:
        print(f'${ername}\t\t\t\t\tNO_REPORTS')
    else:
        r = reports[0]
        gca = r.get('accession','')
        ai = r.get('assembly_info',{})
        status = ai.get('assembly_status','')
        bs_obj = ai.get('biosample',{})
        bs = bs_obj.get('accession','')
        attrs = {a['name']:a['value'] for a in bs_obj.get('attributes',[])}
        st = attrs.get('genotype','').replace('ST ','').replace('ST','').strip()
        cdate = attrs.get('collection_date','')
        print(f'${ername}\t{gca}\t{bs}\t{st}\t{cdate}\t{status}')
except Exception as e:
    print(f'${ername}\t\t\t\t\tERROR')
" >> "$OUT"
        echo "DONE: $ername"
    else
        echo -e "${ername}\t\t\t\t\tNOT_FOUND" >> "$OUT"
        echo "NOT_FOUND: $ername"
    fi
done < "$NAMES"

echo ""
echo "=== 结果 ==="
cat "$OUT" | column -t -s $'\t'
