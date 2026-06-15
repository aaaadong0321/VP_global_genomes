#!/usr/bin/env python3
"""
Deduplicate metadata by Assembly BioSample Accession.

For each BioSample, keep one preferred assembly using:
  1. RefSeq over GenBank
  2. Assembly Level: Complete Genome > Chromosome > Scaffold > Contig
  3. Assembly RefSeq Category: reference genome / representative genome
  4. Fewer contigs
  5. Larger contig N50
  6. Total sequence length closest to normal V. parahaemolyticus genome size

No regional balancing, genome download, or deletion is performed.
"""

from pathlib import Path

import pandas as pd


PROJECT = Path("/Users/guoxiaodong/Desktop/VP_global_genomes")
INPUT = PROJECT / "data/processed/03_geo_available.tsv"
KEPT = PROJECT / "data/processed/04_biosample_deduplicated.tsv"
REMOVED = PROJECT / "data/processed/04_biosample_duplicates_removed.tsv"
SUMMARY = PROJECT / "results/summary/10_biosample_dedup_summary.txt"

BIOSAMPLE_COL = "Assembly BioSample Accession"
ASSEMBLY_COL = "Assembly Accession"
SOURCE_COL = "Source Database"
LEVEL_COL = "Assembly Level"
REFSEQ_CAT_COL = "Assembly Refseq Category"
CONTIGS_COL = "Assembly Stats Number of Contigs"
N50_COL = "Assembly Stats Contig N50"
LEN_COL = "Assembly Stats Total Sequence Length"

EXPECTED_VP_GENOME_SIZE = 5_100_000


def to_num(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce")


def source_rank(value: str) -> int:
    value = str(value).upper()
    if "REFSEQ" in value:
        return 0
    if "GENBANK" in value:
        return 1
    return 2


def level_rank(value: str) -> int:
    ranks = {
        "complete genome": 0,
        "chromosome": 1,
        "scaffold": 2,
        "contig": 3,
    }
    return ranks.get(str(value).strip().lower(), 4)


def refseq_category_rank(value: str) -> int:
    value = str(value).strip().lower()
    if value == "reference genome":
        return 0
    if value == "representative genome":
        return 1
    if value:
        return 2
    return 3


def main() -> None:
    print(f"Input: {INPUT}")
    df = pd.read_csv(INPUT, sep="\t", dtype=str, keep_default_na=False, low_memory=False)

    required = [
        BIOSAMPLE_COL,
        ASSEMBLY_COL,
        SOURCE_COL,
        LEVEL_COL,
        REFSEQ_CAT_COL,
        CONTIGS_COL,
        N50_COL,
        LEN_COL,
    ]
    for col in required:
        if col not in df.columns:
            raise SystemExit(f"Missing required column: {col}")

    work = df.copy()
    # Missing BioSample accessions should not be collapsed together.
    work["_dedup_group"] = work.apply(
        lambda r: r[BIOSAMPLE_COL] if str(r[BIOSAMPLE_COL]).strip() else f"__missing_biosample__{r[ASSEMBLY_COL]}",
        axis=1,
    )
    work["_source_rank"] = work[SOURCE_COL].map(source_rank)
    work["_level_rank"] = work[LEVEL_COL].map(level_rank)
    work["_refseq_category_rank"] = work[REFSEQ_CAT_COL].map(refseq_category_rank)
    work["_contigs_num"] = to_num(work[CONTIGS_COL]).fillna(float("inf"))
    work["_n50_num"] = to_num(work[N50_COL]).fillna(-1)
    work["_length_num"] = to_num(work[LEN_COL])
    work["_length_distance"] = (work["_length_num"] - EXPECTED_VP_GENOME_SIZE).abs().fillna(float("inf"))
    work["_original_order"] = range(len(work))

    sorted_work = work.sort_values(
        by=[
            "_dedup_group",
            "_source_rank",
            "_level_rank",
            "_refseq_category_rank",
            "_contigs_num",
            "_n50_num",
            "_length_distance",
            "_original_order",
        ],
        ascending=[True, True, True, True, True, False, True, True],
        kind="mergesort",
    )

    keep_idx = sorted_work.groupby("_dedup_group", sort=False).head(1).index
    kept = work.loc[keep_idx].sort_values("_original_order").copy()
    removed = work.drop(index=keep_idx).sort_values("_original_order").copy()

    helper_cols = [c for c in kept.columns if c.startswith("_")]
    kept = kept.drop(columns=helper_cols)
    removed = removed.drop(columns=helper_cols)

    KEPT.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    kept.to_csv(KEPT, sep="\t", index=False)
    removed.to_csv(REMOVED, sep="\t", index=False)

    input_unique_biosamples = df.loc[df[BIOSAMPLE_COL].astype(str).str.strip() != "", BIOSAMPLE_COL].nunique()

    with SUMMARY.open("w") as handle:
        handle.write("BioSample deduplication summary\n")
        handle.write(f"Input file: {INPUT}\n")
        handle.write(f"Input total rows: {len(df):,}\n")
        handle.write(f"Input unique BioSample count: {input_unique_biosamples:,}\n")
        handle.write(f"Deduplicated kept rows: {len(kept):,}\n")
        handle.write(f"Removed duplicate rows: {len(removed):,}\n")
        handle.write(f"Deduplicated unique Assembly Accession count: {kept[ASSEMBLY_COL].nunique():,}\n")
        handle.write(f"Deduplicated unique BioSample count: {kept.loc[kept[BIOSAMPLE_COL].astype(str).str.strip() != '', BIOSAMPLE_COL].nunique():,}\n")
        handle.write("\nRemoved records Source Database counts:\n")
        for value, count in removed[SOURCE_COL].value_counts(dropna=False).items():
            display = value if value != "" else "<empty>"
            handle.write(f"{display}\t{count:,}\n")
        handle.write("\nKept records Source Database counts:\n")
        for value, count in kept[SOURCE_COL].value_counts(dropna=False).items():
            display = value if value != "" else "<empty>"
            handle.write(f"{display}\t{count:,}\n")
        handle.write("\nKept records Assembly Level counts:\n")
        for value, count in kept[LEVEL_COL].value_counts(dropna=False).items():
            display = value if value != "" else "<empty>"
            handle.write(f"{display}\t{count:,}\n")

    print(f"Input rows: {len(df):,}")
    print(f"Kept rows: {len(kept):,}")
    print(f"Removed duplicate rows: {len(removed):,}")
    print(f"Wrote: {KEPT}")
    print(f"Wrote: {REMOVED}")
    print(f"Wrote: {SUMMARY}")


if __name__ == "__main__":
    main()
