# VP Global Genomes

This project is for selecting approximately 4,000-5,000 global *Vibrio parahaemolyticus* genomes from NCBI genome metadata for downstream comparative genomic analysis.

No genomes are downloaded at this setup stage. This repository currently contains only the project structure and workflow documentation.

## Project Structure

```text
VP_global_genomes/
├── data/
│   ├── raw/                 # Original NCBI metadata files or imported metadata
│   └── processed/           # Cleaned and filtered metadata tables
├── scripts/                 # Future filtering and summary scripts
├── results/
│   ├── accession_lists/     # Final and intermediate accession lists
│   └── summary/             # Selection summaries and QC summaries
├── logs/                    # Run logs and command records
└── docs/                    # Selection criteria, notes, and manual curation records
```

## Planned Workflow

1. Download or import NCBI genome metadata.
2. Filter records for *Vibrio parahaemolyticus*.
3. Keep genomes from 2019 onwards.
4. Remove records with missing collection year or missing country.
5. Remove duplicate BioSamples.
6. Prioritise RefSeq over GenBank when duplicates exist.
7. Keep all ST50 genomes.
8. Keep all ST36 genomes from 2019 onwards.
9. Keep all ST3 genomes.
10. Keep all New Zealand clinical isolates.
11. Keep New Zealand environmental isolates from the local dataset.
12. Select additional global background genomes balanced by year and geographic region.
13. Generate a final accession list for NCBI Datasets download.

## Expected Outputs

- `data/processed/metadata_cleaned.tsv`
- `data/processed/metadata_filtered.tsv`
- `results/accession_lists/final_accessions.txt`
- `results/summary/selection_summary.tsv`
- `logs/selection_workflow.log`

## Notes

Raw metadata files should remain unchanged in `data/raw/`. Any manual curation decisions, inclusion rules, or exclusion criteria should be documented in `docs/` so that the final genome selection is reproducible.
