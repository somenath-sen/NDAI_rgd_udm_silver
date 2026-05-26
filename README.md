# Diagnosis Data Snapshot — rgd_udm_silver

## Overview
This repository contains the client-facing data snapshot and underlying SQL queries for the `rgd_udm_silver.diagnosis` table hosted on Amazon Web Services (AWS), accessed via MySQL Workbench.

The snapshot summarises 47.9 million diagnosis records across 2.8 million unique patients, with a focus on neurological disease coverage including Alzheimer's Disease, MCI, Multiple Sclerosis, Parkinson's Disease, Migraine, and Epilepsy.

---

## Files

| File | Description |
|---|---|
| `Diagnosis_Snapshot.docx` | One-page client-facing summary of the diagnosis table |
| `diagnosis_queries.sql` | All SQL queries used to generate the snapshot numbers |

---

## Data Source

| Property | Value |
|---|---|
| Platform | Amazon Web Services (AWS) |
| Schema | `rgd_udm_silver` |
| Table | `diagnosis` |
| Access | MySQL Workbench |
| Layer | Silver (structured, cleaned) |
| Total Records | 47,931,830 |
| Unique Patients | 2,798,286 |
| Unique Encounters | 14,826,098 |
| Date Range | 1990 – 2026 |

---

## Snapshot Contents

### Metric Strip
| Metric | Value |
|---|---|
| Total Records | 47.9M |
| Unique Patients | 2.8M |
| Unique Encounters | 14.8M |
| MCI Patients | 62,653 |
| Alzheimer's Patients | 58,074 |

### Patient Population by Disease Area
| Neurological Condition | Unique Patients |
|---|---|
| Migraine | 423,760 |
| Epilepsy & Seizure Disorders | 142,728 |
| Parkinson's Disease | 66,597 |
| Mild Cognitive Impairment | 62,653 |
| Alzheimer's Disease | 58,074 |
| Multiple Sclerosis | 48,811 |
| Rare Neurological Conditions | 10,024 |
| Vascular Dementia | 8,384 |
| Lewy Body Dementia | 3,720 |
| Frontotemporal Dementia | 3,038 |

### Key Clinical Metrics
| Metric | Value |
|---|---|
| Avg diagnoses per patient | ~17.1 |
| Avg diagnoses per encounter | ~3.2 |
| Primary diagnoses (of flagged) | 24.97% |
| Patients with 2+ neurological conditions | 58,659 |
| MCI patients progressing to AD | 7,149 (11.4%) |
| Date range | 1990 – 2026 |

### Data Readiness
| Check | Status |
|---|---|
| Patient & encounter IDs | 100% populated |
| Diagnosis code populated | 99.1% |
| Standardised descriptions | 99.1% |
| Longitudinal date range | 1990 – 2026 |
| Duplicate records | ~12.0% (under review) |
| Source attribution gaps | ~17.7% (under review) |

---

## Query Rules
All queries follow these conventions:
- No `COUNTIF` — use `SUM(CASE WHEN ... THEN 1 ELSE 0 END)`
- `NULLIF()` in all percentage denominators
- `COALESCE()` for date fallback chains
- All null checks combined into a single query
- Unique patients used as the primary metric (not record count)

---

## Notes
- **Duplicate records (~12%)** and **source attribution gaps (~17.7%)** are under review by the data engineering team
- `diag_coding_system_std` should always be used instead of the raw `diag_coding_system` field due to synonym fragmentation (ICD-10/ICD10, ICD-9/ICD9)
- `primary_diagnosis_flag_std` should always be used instead of the raw field which contains mixed text and numeric codes (Y/N/0/1/9)
- Fields not populated in current extract: `diag_status`, `diag_severity`, `provisional_diag_flag`, `differential_diag_flag`, `diag_risk`, `icd_codeset`

---

## Contact
For questions about this repository contact [Somenath Sen / somenath@neurodiscovery.ai].
