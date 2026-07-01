#!/usr/bin/env python3
# 00_mask_reference.py -- RIMD repeat mask (TRF + self-BLASTN) + genome list
import subprocess, os, sys, shutil
P="/workspace/hraxxg/Vp_global_library"
REF=f"{P}/data/reference/RIMD2210633_GCF_000196095.1.fna"
MASKDIR=f"{P}/results/mask"
TI=f"{P}/data/tree_input_v2"
MIN_REP=500; PID=90
os.makedirs(MASKDIR, exist_ok=True); os.chdir(MASKDIR)

for t in ("trf","makeblastdb","blastn","bedtools","sort"):
    if not shutil.which(t): sys.exit(f"ERROR: tool not found: {t} (module loaded?)")
if not os.path.exists(REF): sys.exit(f"ERROR: reference missing: {REF}")
if not os.path.isdir(TI):   sys.exit(f"ERROR: tree_input missing: {TI}")

def run(c, allow_fail=False):
    print("  $", c); r=subprocess.run(c, shell=True)
    if r.returncode!=0 and not allow_fail: sys.exit(f"ERROR: command failed (exit {r.returncode}): {c}")

glen={}; nm=None
for l in open(REF):
    if l.startswith(">"): nm=l[1:].split()[0]; glen[nm]=0
    else: glen[nm]+=len(l.strip())
tot=sum(glen.values()); print("RIMD:", glen, "total", tot)

run(f"trf {REF} 2 7 7 80 10 50 500 -h -ngs > trf.ngs", allow_fail=True)
if not (os.path.exists("trf.ngs") and os.path.getsize("trf.ngs")>0):
    sys.exit("ERROR: TRF produced no output (trf.ngs empty/missing)")
trf_bed=[]; seq=None
for l in open("trf.ngs"):
    l=l.strip()
    if l.startswith("@"): seq=l[1:].split()[0]
    elif l and l.split()[0].isdigit():
        f=l.split(); trf_bed.append((seq,int(f[0])-1,int(f[1])))
if not trf_bed: sys.exit("ERROR: TRF parsed 0 repeats -- unexpected, check trf.ngs")
print("TRF repeats:", len(trf_bed))

run(f"makeblastdb -in {REF} -dbtype nucl -out refdb")
run(f"blastn -query {REF} -db refdb -outfmt '6 qseqid qstart qend sseqid sstart send pident length' -perc_identity {PID} -dust no -evalue 1e-10 > self.blast")
sb_bed=[]
for l in open("self.blast"):
    f=l.rstrip("\n").split("\t")
    if len(f)<8: continue
    q,qs,qe,s,ss,se,ln=f[0],int(f[1]),int(f[2]),f[3],int(f[4]),int(f[5]),int(f[7])
    if q==s and qs==ss and qe==se: continue
    if ln<MIN_REP: continue
    a,b=(qs,qe) if qs<qe else (qe,qs); sb_bed.append((q,a-1,b))
print("self-BLAST hits:", len(sb_bed))

with open("all_rep.bed","w") as f:
    for x in sorted(trf_bed+sb_bed): f.write(f"{x[0]}\t{x[1]}\t{x[2]}\n")
run("sort -k1,1 -k2,2n all_rep.bed | bedtools merge -i - > ref.mask.bed")
if not (os.path.exists("ref.mask.bed") and os.path.getsize("ref.mask.bed")>0):
    sys.exit("ERROR: ref.mask.bed empty -- bedtools merge failed")
mask=sum(int(e)-int(s) for _,s,e in (ln.split() for ln in open("ref.mask.bed")))
ivl=sum(1 for _ in open("ref.mask.bed")); frac=100*mask/tot
print(f"masked {mask}/{tot} bp ({frac:.2f}%), {ivl} intervals")

gids=sorted(fn[:-4] for fn in os.listdir(TI) if fn.endswith(".fna"))
open(f"{TI}/genome_list.txt","w").write("\n".join(gids)+"\n")
print(f"genome_list: {len(gids)} -> {TI}/genome_list.txt")

with open("mask_summary.txt","w") as f:
    f.write("# RIMD repeat-mask summary (step 00)\n")
    f.write(f"reference_path\t{REF}\n")
    f.write(f"reference_length_bp\t{tot}\n")
    f.write(f"reference_contigs\t{';'.join(f'{k}:{v}' for k,v in glen.items())}\n")
    f.write(f"TRF_repeat_intervals\t{len(trf_bed)}\n")
    f.write(f"selfBLAST_repeat_intervals\t{len(sb_bed)}\n")
    f.write(f"merged_mask_intervals\t{ivl}\n")
    f.write(f"masked_bp\t{mask}\n")
    f.write(f"masked_fraction_pct\t{frac:.3f}\n")
    f.write(f"param_MIN_REP_bp\t{MIN_REP}\n")
    f.write(f"param_self_blast_pident\t{PID}\n")
    f.write(f"param_TRF\t2 7 7 80 10 50 500\n")
    f.write(f"genome_list_n\t{len(gids)}\n")
print(f"summary -> {MASKDIR}/mask_summary.txt")

if frac<0.1: print("WARNING: masked <0.1% -- repeats barely detected; check params")
elif frac>20: print("WARNING: masked >20% -- mask too aggressive; check params")
else: print("OK: masked fraction in expected range")
