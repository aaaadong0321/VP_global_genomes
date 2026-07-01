#!/usr/bin/env python3
# 02_build_core_snp.py -- core-SNP alignment from nucmer .snps/.coords (pure stdlib)
import os, sys, bisect
from array import array
P="/workspace/hraxxg/Vp_global_library"
REF=f"{P}/data/reference/RIMD2210633_GCF_000196095.1.fna"
NUC=f"{P}/results/nucmer"
MASKBED=f"{P}/results/mask/ref.mask.bed"
LIST=f"{P}/data/tree_input_v2/genome_list.txt"
OUT=f"{P}/results/core_snp"
THRS=[99,97,95]
os.makedirs(OUT, exist_ok=True)
ACGT=set("ACGT")
genomes=[l.strip() for l in open(LIST) if l.strip()]
N=len(genomes); print(f"genomes: {N}")
clen={}; nm=None
for l in open(REF):
    if l.startswith(">"): nm=l[1:].split()[0]; clen[nm]=0
    else: clen[nm]+=len(l.strip())
print("chroms:", clen)
mask={c:bytearray(L) for c,L in clen.items()}
for l in open(MASKBED):
    f=l.split()
    if len(f)>=3 and f[0] in mask:
        for p in range(int(f[1]),int(f[2])): mask[f[0]][p]=1
def cols(line): return line.rstrip("\n").split("\t")
cov={c:array('i',[0]*(L+1)) for c,L in clen.items()}
snpref={}; miss=0
for gi,g in enumerate(genomes):
    sf=f"{NUC}/{g}.snps"; cf=f"{NUC}/{g}.coords"
    if not (os.path.exists(sf) and os.path.exists(cf)): miss+=1; continue
    for line in open(cf):
        f=cols(line)
        if len(f)<12: continue
        try: s1=int(f[0]); e1=int(f[1])
        except ValueError: continue
        c=f[11]
        if c not in cov: continue
        if s1>e1: s1,e1=e1,s1
        cov[c][s1-1]+=1; cov[c][e1]-=1
    for line in open(sf):
        f=cols(line)
        if len(f)<9: continue
        rb=f[1].upper(); qb=f[2].upper()
        if rb not in ACGT or qb not in ACGT: continue
        try: pos=int(f[0])
        except ValueError: continue
        if f[8] in clen: snpref[(f[8],pos)]=rb
    if (gi+1)%1000==0: print(f"  pass1 {gi+1}/{N}", flush=True)
print(f"missing files: {miss}; variable sites: {len(snpref)}")
for c in cov:
    a=cov[c]; r=0
    for i in range(len(a)): r+=a[i]; a[i]=r
need={T:(T*N+99)//100 for T in THRS}
print("min genomes per threshold:", need)
need95=min(need.values())
sites=[(c,pos,rb) for (c,pos),rb in snpref.items() if not mask[c][pos-1] and cov[c][pos-1]>=need95]
sites.sort()
covsite=[cov[c][pos-1] for c,pos,rb in sites]
print(f"core sites (95%, >= {need95}): {len(sites)}")
for T in THRS:
    print(f"  t{T}%: >= {need[T]} -> {sum(1 for x in covsite if x>=need[T])} sites")
if not sites: sys.exit("0 core sites")
bychrom={}
for idx,(c,pos,rb) in enumerate(sites):
    bychrom.setdefault(c,([],[]))[0].append(pos); bychrom[c][1].append(idx)
refb=[ord(s[2]) for s in sites]
print("building matrix...", flush=True)
mat=[bytearray(b"N")*len(sites) for _ in range(N)]
for gi,g in enumerate(genomes):
    sf=f"{NUC}/{g}.snps"; cf=f"{NUC}/{g}.coords"
    if not (os.path.exists(sf) and os.path.exists(cf)): continue
    row=mat[gi]
    for line in open(cf):
        f=cols(line)
        if len(f)<12: continue
        try: s1=int(f[0]); e1=int(f[1])
        except ValueError: continue
        c=f[11]
        if c not in bychrom: continue
        if s1>e1: s1,e1=e1,s1
        posl,idxl=bychrom[c]
        for k in range(bisect.bisect_left(posl,s1), bisect.bisect_right(posl,e1)):
            row[idxl[k]]=refb[idxl[k]]
    for line in open(sf):
        f=cols(line)
        if len(f)<9: continue
        rb=f[1].upper(); qb=f[2].upper()
        if rb not in ACGT or qb not in ACGT: continue
        try: pos=int(f[0])
        except ValueError: continue
        c=f[8]
        if c not in bychrom: continue
        posl,idxl=bychrom[c]
        j=bisect.bisect_left(posl,pos)
        if j<len(posl) and posl[j]==pos: row[idxl[j]]=ord(qb)
    if (gi+1)%1000==0: print(f"  matrix {gi+1}/{N}", flush=True)
for T in THRS:
    keep=[i for i in range(len(sites)) if covsite[i]>=need[T]]
    full=(len(keep)==len(sites))
    fa=f"{OUT}/core_snps.t{T}.fasta"
    with open(fa,"w") as f:
        for gi,g in enumerate(genomes):
            f.write(f">{g}\n")
            f.write((mat[gi].decode() if full else bytes(mat[gi][i] for i in keep).decode())+"\n")
    print(f"t{T}: {fa}  ({N} x {len(keep)} sites)")
with open(f"{OUT}/positions.tsv","w") as f:
    f.write("chrom\tref_pos\tref_base\tn_cov\tt99\tt97\tt95\n")
    for i,(c,pos,rb) in enumerate(sites):
        nc=covsite[i]
        f.write(f"{c}\t{pos}\t{rb}\t{nc}\t{int(nc>=need[99])}\t{int(nc>=need[97])}\t{int(nc>=need[95])}\n")
with open(f"{OUT}/core_snp.stats.tsv","w") as f:
    f.write("threshold_pct\tmin_genomes\tcore_snp_sites\n")
    for T in THRS: f.write(f"{T}\t{need[T]}\t{sum(1 for x in covsite if x>=need[T])}\n")
print(f"\nstats -> {OUT}/core_snp.stats.tsv\nDONE")
