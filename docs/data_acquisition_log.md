# Data Acquisition Log

This file records the data acquisition and filtering decisions for the global
*Vibrio parahaemolyticus* background tree. It is intended to satisfy the
reproducibility record requested by Charles: exact query terms or commands,
accession versions, download date, filtering criteria, and count changes.

## Project Paths

- Project directory: `/Users/guoxiaodong/Desktop/VP_global_genomes`
- Raw NCBI metadata: `data/raw/ncbi_vp_metadata.tsv`
- NCBI metadata package: `data/raw/ncbi_vp_metadata_package.zip`
- Processed metadata: `data/processed/`
- Summary outputs: `results/summary/`
- Accession lists: `results/accession_lists/`
- Command logs: `logs/`

## NCBI 2019+ Background Download

- Recorded run date: `2026-05-28` based on existing project logs and file timestamps; confirm this date before manuscript submission.
- Tool: NCBI Datasets CLI
- CLI version currently available in this environment: `datasets version: 18.21.0`
- Taxon: *Vibrio parahaemolyticus*
- NCBI taxon ID: `670`
- Assembly source: GenBank + RefSeq as returned by NCBI Datasets; no explicit assembly-source filter was used in the recorded command.
- Recorded command:

```bash
cd /Users/guoxiaodong/Desktop/VP_global_genomes
datasets download genome taxon 670 --include none --filename data/raw/ncbi_vp_metadata_package.zip
unzip -q data/raw/ncbi_vp_metadata_package.zip -d data/raw/ncbi_vp_metadata_package/
dataformat tsv genome --inputfile data/raw/ncbi_vp_metadata_package/ncbi_dataset/data/assembly_data_report.jsonl > data/raw/ncbi_vp_metadata.tsv
```

- Command record: `logs/00_download_metadata_commands.txt`
- Run log: `logs/00_download_metadata.log`
- Note: the first attempt in the log failed because of a temporary DNS issue; the subsequent retry collected `19,546` genome records.

## Additional Data Sources To Record

### PFR / PowerPlant Local Assemblies

- Source directory: `TBD`
- Date copied: `TBD`
- Number of PFR NZ ST50 assemblies: `TBD`
- Number of PFR NZ non-ST50 assemblies: `TBD`
- Notes: PFR local assemblies should be preferred over duplicate NCBI public assemblies during BioSample deduplication.

### Pre-2019 ST50 Supplement

- Source list: Paper 3 ST50 strain list
- Date downloaded/copied: `TBD`
- Download method or command: `TBD`
- Accession list file: `results/accession_lists/pre_2019_st50_accessions.tsv`
- Notes: all ST50 genomes are retained regardless of year, so pre-2019 ST50 baseline strains must be added to the main analysis, not only to a sensitivity analysis.

### ESR NZ ST50 Accessions

- Source list: Paper 3 ESR NZ ST50 accession list
- Date checked: `TBD`
- Output file: `results/accession_lists/esr_nz_st50_accessions_checked.tsv`
- Notes: strains covered by the NCBI 2019+ download should be marked as retrieved. Any missing ESR ST50 strain should be downloaded separately by accession or assembled from reads.

### PubMLST-Only ST50 Assemblies

- Source directory or file list: `TBD`
- Date copied: `TBD`
- Output file: `results/accession_lists/pubmlst_only_st50_assemblies.tsv`
- Notes: if no NCBI assembly is available, record the PubMLST assembly file used and its provenance.

## Filtering Steps

The current count table reflects the existing NCBI 2019+ public background workflow already present in this project. Update this table after the final merged workflow adds PFR local assemblies, all-year ST50 genomes, pre-2019 ST50 supplements, PubMLST-only assemblies, and any read-derived assemblies.

| Step | Criteria | Count | Source file / log |
|---|---|---:|---|
| Raw metadata TSV rows | Rows after `dataformat tsv genome`; includes expanded BioSample attribute rows | 400,314 | `logs/01_collapse_metadata.log` |
| One row per assembly | Collapsed metadata to one row per assembly | 19,546 | `data/processed/00_metadata_one_row_per_assembly.tsv` |
| Species label filter | `ANI Submitted species == Vibrio parahaemolyticus` | 19,546 | `results/summary/06_species_filter_corrected_summary.txt` |
| Collection year extracted | Records with extractable collection year | 18,318 | `results/summary/06_year_filter_summary.txt` |
| Collection year missing | Records without extractable collection year | 1,228 | `results/summary/06_year_filter_summary.txt` |
| Collection year >= 2019 | Contemporary public background pool before geography filtering | 7,700 | `data/processed/02_year_2019_onwards.tsv` |
| Collection year < 2019 | Excluded from the 2019+ public background pool, except all ST50 genomes must be recovered through the ST50 supplement | 10,618 | `data/processed/02_year_excluded.tsv` |
| Geographic metadata present | `geo_loc_name` or fallback geography field present | 7,633 | `data/processed/03_geo_available.tsv` |
| Geographic metadata missing | Excluded from 2019+ public background pool | 67 | `data/processed/03_geo_excluded.tsv` |
| BioSample deduplication | One representative assembly per BioSample | 6,061 | `data/processed/04_biosample_deduplicated.tsv` |
| Duplicate assemblies removed | Duplicate BioSample records removed | 1,572 | `data/processed/04_biosample_duplicates_removed.tsv` |
| PFR local assemblies added | Add PowerPlant PFR local assemblies | TBD | `TBD` |
| Pre-2019 ST50 added | Add Paper 3 pre-2019 ST50 baseline assemblies | TBD | `TBD` |
| PubMLST-only ST50 added | Add ST50 assemblies available only through PubMLST | TBD | `TBD` |
| ESR missing assemblies resolved | Download by accession or assemble from reads if not covered by NCBI | TBD | `TBD` |
| Unified MLST assignment | Run `mlst` on all merged assemblies; Paper 3 181 ST50 use Paper 3 MLST calls | TBD | `TBD` |
| ST50 retained set | All ST50 isolates retained regardless of year or country | TBD | `results/accession_lists/st50_retained_set.tsv` |
| ANI species confirmation | fastANI/skani to RIMD2210633, retain ANI >95% | TBD | `TBD` |
| Assembly QC | completeness >90%, contamination <5%, QUAST metrics checked | TBD | `TBD` |
| Final pre-downsampling merged set | After merge, deduplication, ANI, and assembly QC | TBD | `TBD` |
| Final downsampled phylogenetic set | MLST + metadata downsampling; all ST50 retained | TBD | `results/accession_lists/final_phylogenetic_set_accessions.tsv` |

## Output Files To Maintain

| Output | Path | Status |
|---|---|---|
| Raw NCBI metadata | `data/raw/ncbi_vp_metadata.tsv` | present |
| One-row-per-assembly metadata | `data/processed/00_metadata_one_row_per_assembly.tsv` | present |
| Current 2019+ deduplicated public pool | `data/processed/04_biosample_deduplicated.tsv` | present |
| PFR local assembly manifest | `results/accession_lists/pfr_local_assemblies.tsv` | TBD |
| Paper 3 181 ST50 list | `results/accession_lists/paper3_181_st50_list.tsv` | TBD |
| Pre-2019 ST50 accession list | `results/accession_lists/pre_2019_st50_accessions.tsv` | TBD |
| ESR NZ ST50 accession check | `results/accession_lists/esr_nz_st50_accessions_checked.tsv` | TBD |
| Newly identified ST50 list | `results/accession_lists/new_st50_from_global_mlst.tsv` | TBD |
| ST50 retained set | `results/accession_lists/st50_retained_set.tsv` | TBD |
| Filtering summary | `results/summary/filtering_summary_final.tsv` | TBD |
| Final assembly accession versions | `results/accession_lists/final_assembly_accessions.tsv` | TBD |
| Final master genome list | `data/processed/final_master_genome_list.tsv` | TBD |

## Required Columns For Final Master Genome List

The final master genome list should contain one row per retained assembly.

| Column | Description |
|---|---|
| `genome_id` | Internal genome identifier |
| `strain_name` | Strain name used in Paper 3 or metadata |
| `source` | `PFR_local`, `NCBI_public`, `PubMLST`, or `reads_assembly` |
| `assembly_accession_version` | Full accession with version, e.g. `GCA_XXXXXX.1` or `GCF_XXXXXX.2` |
| `biosample` | BioSample accession |
| `bioproject` | BioProject accession |
| `country` | Harmonised country field |
| `geo_loc_name_raw` | Raw geographic metadata |
| `collection_year` | Extracted collection year |
| `ST` | Final sequence type |
| `ST_source` | `Paper3_MLST` for Paper 3 181 ST50; otherwise `current_mlst` |
| `is_ST50` | `yes` or `no` |
| `ST50_retained_set` | `yes` or `no` |
| `is_paper3_181_ST50` | `yes` or `no` |
| `is_pre_2019_ST50` | `yes` or `no` |
| `dedup_status` | `kept` or `removed_duplicate` |
| `dedup_reason` | Reason for retention/removal |
| `ANI_to_RIMD2210633` | ANI value |
| `ANI_filter_status` | `pass`, `borderline_review`, or `fail` |
| `completeness` | CheckM2/CheckM completeness |
| `contamination` | CheckM2/CheckM contamination |
| `N50` | QUAST N50 |
| `contig_count` | QUAST contig count |
| `genome_size` | QUAST total length |
| `QC_status` | `pass` or `fail` |
| `downsampling_status` | `kept`, `removed`, or `not_applicable` |
| `downsampling_reason` | Rule used for downsampling |

## Reproducibility Notes

- Always retain accession versions, not only accession stems.
- Keep the exact NCBI Datasets command and CLI version for each rerun.
- If NCBI Datasets CLI is updated before the final download, record the new version and command separately rather than overwriting the older record.
- Store every intermediate accession list used for filtering, ST50 recovery, and downsampling.
- Do not manually edit count tables after filtering; generate final counts from scripts whenever possible.
- All ST50 genomes should be retained regardless of year or country unless they fail species confirmation or assembly QC, in which case the exclusion reason must be recorded.
