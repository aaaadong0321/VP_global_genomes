#!/usr/bin/env python3
"""
Filter records to those with available geographic metadata.

Uses Assembly BioSample Geographic location as the primary source and
biosample_attr_geo_loc_name as fallback. Adds geo_location_final.

No BioSample deduplication, regional balancing, genome download, or deletion is performed.
"""

from pathlib import Path

import pandas as pd


PROJECT = Path("/Users/guoxiaodong/Desktop/VP_global_genomes")
INPUT = PROJECT / "data/processed/02_year_2019_onwards.tsv"
KEPT = PROJECT / "data/processed/03_geo_available.tsv"
EXCLUDED = PROJECT / "data/processed/03_geo_excluded.tsv"
SUMMARY = PROJECT / "results/summary/08_geo_filter_summary.txt"

PRIMARY_GEO_COL = "Assembly BioSample Geographic location"
FALLBACK_GEO_COL = "biosample_attr_geo_loc_name"
FINAL_GEO_COL = "geo_location_final"
ASSEMBLY_COL = "Assembly Accession"

MISSING_VALUES = {
    "",
    "missing",
    "not provided",
    "not collected",
    "na",
    "n/a",
    "null",
    "none",
    "unknown",
}


def clean_geo(value: str) -> str:
    value = str(value).strip()
    return "" if value.lower() in MISSING_VALUES else value


def main() -> None:
    print(f"Input: {INPUT}")
    print(f"Primary geography column: {PRIMARY_GEO_COL}")
    print(f"Fallback geography column: {FALLBACK_GEO_COL}")

    df = pd.read_csv(INPUT, sep="\t", dtype=str, keep_default_na=False, low_memory=False)
    for col in [PRIMARY_GEO_COL, ASSEMBLY_COL]:
        if col not in df.columns:
            raise SystemExit(f"Missing required column: {col}")
    if FALLBACK_GEO_COL not in df.columns:
        print(f"Warning: fallback column not found: {FALLBACK_GEO_COL}")
        df[FALLBACK_GEO_COL] = ""

    primary = df[PRIMARY_GEO_COL].map(clean_geo)
    fallback = df[FALLBACK_GEO_COL].map(clean_geo)
    df[FINAL_GEO_COL] = primary.where(primary != "", fallback)

    keep_mask = df[FINAL_GEO_COL] != ""
    kept = df.loc[keep_mask].copy()
    excluded = df.loc[~keep_mask].copy()

    KEPT.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    kept.to_csv(KEPT, sep="\t", index=False)
    excluded.to_csv(EXCLUDED, sep="\t", index=False)

    top_geo = kept[FINAL_GEO_COL].value_counts(dropna=False).head(50)

    with SUMMARY.open("w") as handle:
        handle.write("Geographic metadata availability filter summary\n")
        handle.write(f"Input file: {INPUT}\n")
        handle.write(f"Primary geography column: {PRIMARY_GEO_COL}\n")
        handle.write(f"Fallback geography column: {FALLBACK_GEO_COL}\n")
        handle.write(f"Input total rows: {len(df):,}\n")
        handle.write(f"geo_location_final non-empty kept count: {len(kept):,}\n")
        handle.write(f"geo_location_final missing excluded count: {len(excluded):,}\n")
        handle.write(f"Kept unique Assembly Accession count: {kept[ASSEMBLY_COL].nunique():,}\n")
        handle.write(f"Excluded unique Assembly Accession count: {excluded[ASSEMBLY_COL].nunique():,}\n")
        handle.write("\ngeo_location_final top 50 value counts:\n")
        for value, count in top_geo.items():
            handle.write(f"{value}\t{count:,}\n")

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
