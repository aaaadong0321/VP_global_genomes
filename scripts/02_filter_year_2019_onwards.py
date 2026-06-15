#!/usr/bin/env python3
"""
Filter species-confirmed NCBI metadata to genomes collected from 2019 onward.

Rules:
  - Extract year from Assembly BioSample Collection date.
  - Keep records with extracted year >= 2019.
  - Exclude records with missing/unparseable year.
  - Exclude records with extracted year < 2019.

No geographic filtering, BioSample deduplication, genome download, or deletion is performed.
"""

from pathlib import Path
import re

import pandas as pd


PROJECT = Path("/Users/guoxiaodong/Desktop/VP_global_genomes")
INPUT = PROJECT / "data/processed/01_species_confirmed.tsv"
KEPT = PROJECT / "data/processed/02_year_2019_onwards.tsv"
EXCLUDED = PROJECT / "data/processed/02_year_excluded.tsv"
SUMMARY = PROJECT / "results/summary/06_year_filter_summary.txt"

DATE_COL = "Assembly BioSample Collection date"
ASSEMBLY_COL = "Assembly Accession"
YEAR_COL = "collection_year"


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


def is_missing(value: str) -> bool:
    return str(value).strip().lower() in MISSING_VALUES


def extract_year(value: str):
    if is_missing(value):
        return pd.NA
    match = re.search(r"(?<!\d)(19\d{2}|20\d{2})(?!\d)", str(value).strip())
    if not match:
        return pd.NA
    year = int(match.group(1))
    if 1900 <= year <= 2100:
        return year
    return pd.NA


def main() -> None:
    print(f"Input: {INPUT}")
    print("Keep rule: extracted collection year >= 2019")

    df = pd.read_csv(INPUT, sep="\t", dtype=str, keep_default_na=False, low_memory=False)
    for col in [DATE_COL, ASSEMBLY_COL]:
        if col not in df.columns:
            raise SystemExit(f"Missing required column: {col}")

    df[YEAR_COL] = df[DATE_COL].map(extract_year).astype("Int64")

    has_year = df[YEAR_COL].notna()
    keep_mask = has_year & (df[YEAR_COL] >= 2019)
    pre_2019_mask = has_year & (df[YEAR_COL] < 2019)
    no_year_mask = ~has_year

    kept = df.loc[keep_mask].copy()
    excluded = df.loc[~keep_mask].copy()

    KEPT.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    kept.to_csv(KEPT, sep="\t", index=False)
    excluded.to_csv(EXCLUDED, sep="\t", index=False)

    kept_year_counts = kept[YEAR_COL].value_counts().sort_index()

    with SUMMARY.open("w") as handle:
        handle.write("Year filter summary: 2019 onwards\n")
        handle.write(f"Input file: {INPUT}\n")
        handle.write(f"Input total rows: {len(df):,}\n")
        handle.write(f"Successfully extracted year count: {has_year.sum():,}\n")
        handle.write(f"Unable to extract year count: {no_year_mask.sum():,}\n")
        handle.write(f"year >= 2019 kept count: {keep_mask.sum():,}\n")
        handle.write(f"year < 2019 excluded count: {pre_2019_mask.sum():,}\n")
        handle.write(f"Final kept unique Assembly Accession count: {kept[ASSEMBLY_COL].nunique():,}\n")
        handle.write(f"Final excluded unique Assembly Accession count: {excluded[ASSEMBLY_COL].nunique():,}\n")
        handle.write("\nKept genome count by extracted year:\n")
        for year, count in kept_year_counts.items():
            handle.write(f"{int(year)}\t{count:,}\n")

    print(f"Input rows: {len(df):,}")
    print(f"Successfully extracted year: {has_year.sum():,}")
    print(f"Unable to extract year: {no_year_mask.sum():,}")
    print(f"Kept year >= 2019: {keep_mask.sum():,}")
    print(f"Excluded year < 2019: {pre_2019_mask.sum():,}")
    print(f"Wrote: {KEPT}")
    print(f"Wrote: {EXCLUDED}")
    print(f"Wrote: {SUMMARY}")


if __name__ == "__main__":
    main()
