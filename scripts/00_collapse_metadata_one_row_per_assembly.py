#!/usr/bin/env python3
"""
Collapse NCBI dataformat genome metadata from expanded BioSample-attribute rows
to one row per Assembly Accession.

No filtering is performed. The raw metadata file is read-only.
"""

from __future__ import annotations

import re
from pathlib import Path

import pandas as pd


PROJECT = Path("/Users/guoxiaodong/Desktop/VP_global_genomes")
INPUT = PROJECT / "data/raw/ncbi_vp_metadata.tsv"
OUTPUT = PROJECT / "data/processed/00_metadata_one_row_per_assembly.tsv"

ASSEMBLY_COL = "Assembly Accession"
ATTR_NAME_COL = "Assembly BioSample Attribute Name"
ATTR_VALUE_COL = "Assembly BioSample Attribute Value"


KEY_COLUMNS = [
    "Assembly Accession",
    "Current Accession",
    "Source Database",
    "Organism Name",
    "Organism Taxonomic ID",
    "Assembly BioSample Accession",
    "Assembly BioSample Collection date",
    "Assembly BioSample Geographic location",
    "Assembly BioSample Isolation source",
    "Assembly BioSample Host",
    "Assembly BioSample Strain",
    "Assembly BioSample Isolate",
    "Assembly Level",
    "Assembly Refseq Category",
    "Assembly Status",
    "Assembly Release Date",
    "Assembly Stats Total Sequence Length",
    "Assembly Stats Number of Contigs",
    "Assembly Stats Contig N50",
    "CheckM completeness",
    "CheckM contamination",
]


def first_non_empty(values: pd.Series) -> str:
    for value in values:
        if pd.notna(value) and str(value) != "":
            return str(value)
    return ""


def safe_attr_name(name: str) -> str:
    name = str(name).strip().lower()
    name = re.sub(r"[^a-z0-9]+", "_", name)
    name = re.sub(r"_+", "_", name).strip("_")
    return f"biosample_attr_{name}" if name else ""


def join_unique_non_empty(values: pd.Series) -> str:
    seen: list[str] = []
    for value in values:
        if pd.isna(value):
            continue
        value = str(value)
        if value == "" or value in seen:
            continue
        seen.append(value)
    return " | ".join(seen)


def main() -> None:
    print(f"Input: {INPUT}")
    print(f"Output: {OUTPUT}")

    df = pd.read_csv(INPUT, sep="\t", dtype=str, keep_default_na=False, low_memory=False)
    print(f"Loaded rows: {len(df):,}")
    print(f"Loaded columns: {len(df.columns):,}")

    if ASSEMBLY_COL not in df.columns:
        raise SystemExit(f"Missing required column: {ASSEMBLY_COL}")
    if ATTR_NAME_COL not in df.columns or ATTR_VALUE_COL not in df.columns:
        raise SystemExit(f"Missing required BioSample attribute columns: {ATTR_NAME_COL}, {ATTR_VALUE_COL}")

    ordinary_cols = [c for c in df.columns if c not in {ATTR_NAME_COL, ATTR_VALUE_COL}]
    collapsed = df.groupby(ASSEMBLY_COL, sort=False, dropna=False)[ordinary_cols].agg(first_non_empty)
    collapsed = collapsed.reset_index(drop=True)

    attr_df = df[[ASSEMBLY_COL, ATTR_NAME_COL, ATTR_VALUE_COL]].copy()
    attr_df["safe_attr_col"] = attr_df[ATTR_NAME_COL].map(safe_attr_name)
    attr_df = attr_df[(attr_df["safe_attr_col"] != "") & (attr_df[ATTR_VALUE_COL] != "")]

    if not attr_df.empty:
        attr_wide = (
            attr_df.groupby([ASSEMBLY_COL, "safe_attr_col"], sort=False)[ATTR_VALUE_COL]
            .agg(join_unique_non_empty)
            .unstack(fill_value="")
            .reset_index()
        )
        collapsed = collapsed.merge(attr_wide, on=ASSEMBLY_COL, how="left")

    attr_cols = sorted([c for c in collapsed.columns if c.startswith("biosample_attr_")])
    missing_key_cols = [c for c in KEY_COLUMNS if c not in collapsed.columns]
    if missing_key_cols:
        raise SystemExit(f"Missing expected key columns after collapse: {missing_key_cols}")

    remaining_cols = [c for c in collapsed.columns if c not in KEY_COLUMNS and not c.startswith("biosample_attr_")]
    final_cols = KEY_COLUMNS + remaining_cols + attr_cols
    collapsed = collapsed[final_cols]

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    collapsed.to_csv(OUTPUT, sep="\t", index=False)

    print(f"Collapsed rows: {len(collapsed):,}")
    print(f"Collapsed columns: {len(collapsed.columns):,}")
    print(f"Unique Assembly Accession: {collapsed[ASSEMBLY_COL].nunique():,}")
    print(f"Expanded BioSample attribute columns: {len(attr_cols):,}")


if __name__ == "__main__":
    main()
