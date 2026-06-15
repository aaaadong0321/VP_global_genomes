#!/usr/bin/env python3
"""
Species confirmation filter for collapsed NCBI metadata.

Keep records where ANI Submitted species == Vibrio parahaemolyticus.

No year filtering, geographic filtering, BioSample deduplication, or genome
download is performed.
"""

from pathlib import Path

import pandas as pd


PROJECT = Path("/Users/guoxiaodong/Desktop/VP_global_genomes")
INPUT = PROJECT / "data/processed/00_metadata_one_row_per_assembly.tsv"
KEPT = PROJECT / "data/processed/01_species_confirmed.tsv"
EXCLUDED = PROJECT / "data/processed/01_species_excluded.tsv"
SUMMARY = PROJECT / "results/summary/04_species_filter_summary.txt"

SPECIES = "Vibrio parahaemolyticus"
ANI_SPECIES_COL = "ANI Submitted species"
ORGANISM_COL = "Organism Name"
ASSEMBLY_COL = "Assembly Accession"


def main() -> None:
    print(f"Input: {INPUT}")
    print(f"Keep rule: {ANI_SPECIES_COL} == {SPECIES}")

    df = pd.read_csv(INPUT, sep="\t", dtype=str, keep_default_na=False, low_memory=False)
    for col in [ANI_SPECIES_COL, ORGANISM_COL, ASSEMBLY_COL]:
        if col not in df.columns:
            raise SystemExit(f"Missing required column: {col}")

    ani_counts = df[ANI_SPECIES_COL].value_counts(dropna=False).sort_index()
    organism_top20 = df[ORGANISM_COL].value_counts(dropna=False).head(20)

    keep_mask = df[ANI_SPECIES_COL] == SPECIES
    kept = df.loc[keep_mask].copy()
    excluded = df.loc[~keep_mask].copy()

    KEPT.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    kept.to_csv(KEPT, sep="\t", index=False)
    excluded.to_csv(EXCLUDED, sep="\t", index=False)

    with SUMMARY.open("w") as handle:
        handle.write("Species confirmation filter summary\n")
        handle.write(f"Input file: {INPUT}\n")
        handle.write(f"Keep rule: {ANI_SPECIES_COL} == {SPECIES}\n")
        handle.write(f"Input total rows: {len(df):,}\n")
        handle.write(f"Kept rows: {len(kept):,}\n")
        handle.write(f"Excluded rows: {len(excluded):,}\n")
        handle.write(f"Kept unique Assembly Accession count: {kept[ASSEMBLY_COL].nunique():,}\n")
        handle.write(f"Excluded unique Assembly Accession count: {excluded[ASSEMBLY_COL].nunique():,}\n")
        handle.write("\nANI Submitted species value counts:\n")
        for value, count in ani_counts.items():
            display = value if value != "" else "<empty>"
            handle.write(f"{display}\t{count:,}\n")
        handle.write("\nOrganism Name top 20 value counts:\n")
        for value, count in organism_top20.items():
            display = value if value != "" else "<empty>"
            handle.write(f"{display}\t{count:,}\n")

    print(f"Input rows: {len(df):,}")
    print(f"Kept rows: {len(kept):,}")
    print(f"Excluded rows: {len(excluded):,}")
    print(f"Kept unique Assembly Accession: {kept[ASSEMBLY_COL].nunique():,}")
    print(f"Excluded unique Assembly Accession: {excluded[ASSEMBLY_COL].nunique():,}")
    print(f"Wrote: {KEPT}")
    print(f"Wrote: {EXCLUDED}")
    print(f"Wrote: {SUMMARY}")


if __name__ == "__main__":
    main()
