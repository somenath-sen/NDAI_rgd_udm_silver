-- ============================================================
-- FILE: diagnosis_queries.sql
-- TABLE: rgd_udm_silver.diagnosis
-- DESCRIPTION: All SQL queries used to generate the numbers
--              in the Diagnosis Data Snapshot (Diagnosis_Snapshot.docx)
-- DATABASE: rgd_udm_silver.diagnosis
-- ACCESS: MySQL Workbench (via AWS VPN)
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- SECTION 1: METRIC STRIP
-- Total records, unique patients, unique encounters,
-- MCI patients, Alzheimer's patients
-- ────────────────────────────────────────────────────────────

-- Total records, unique patients, unique encounters
SELECT
  COUNT(*)                AS total_records,
  COUNT(DISTINCT ndid)    AS unique_patients,
  COUNT(DISTINCT eid)     AS unique_encounters
FROM rgd_udm_silver.diagnosis;


-- MCI patients (G31.84)
SELECT COUNT(DISTINCT ndid) AS mci_unique_patients
FROM rgd_udm_silver.diagnosis
WHERE diag_code = 'G31.84'
  AND diag_coding_system_std IN ('ICD-10','ICD-9');


-- Alzheimer's patients (all G30 subtypes + ICD-9 331.0)
-- Uses COUNT(DISTINCT ndid) to avoid double-counting patients
-- with multiple AD codes across encounters
SELECT COUNT(DISTINCT ndid) AS ad_unique_patients
FROM rgd_udm_silver.diagnosis
WHERE diag_code IN ('G30.0','G30.1','G30.8','G30.9','331.0')
  AND diag_coding_system_std IN ('ICD-10','ICD-9');


-- ────────────────────────────────────────────────────────────
-- SECTION 2: PATIENT POPULATION BY DISEASE AREA
-- ────────────────────────────────────────────────────────────

SELECT
  CASE
    WHEN diag_code IN ('G30.0','G30.1','G30.8','G30.9','331.0')
         THEN 'Alzheimers Disease'
    WHEN diag_code = 'G31.84'
         THEN 'Mild Cognitive Impairment'
    WHEN diag_code IN ('G35','340')
         THEN 'Multiple Sclerosis'
    WHEN diag_code LIKE 'G43%'
         OR diag_code IN ('346.00','346.10','346.90')
         THEN 'Migraine'
    WHEN diag_code LIKE 'G20%'
         OR diag_code IN ('332.0','332.1')
         THEN 'Parkinsons Disease'
    WHEN diag_code LIKE 'G40%'
         OR diag_code LIKE 'G41%'
         OR diag_code IN ('345.00','345.10','345.90')
         THEN 'Epilepsy and Seizure Disorders'
    WHEN diag_code LIKE 'F01%'
         THEN 'Vascular Dementia'
    WHEN diag_code = 'G31.83'
         THEN 'Lewy Body Dementia'
    WHEN diag_code IN ('G31.01','G31.09')
         THEN 'Frontotemporal Dementia'
    WHEN diag_code LIKE 'G10%'
         OR diag_code LIKE 'G11%'
         OR diag_code LIKE 'G12%'
         THEN 'Rare Neurological Conditions'
  END AS disease_group,
  COUNT(DISTINCT ndid) AS unique_patients
FROM rgd_udm_silver.diagnosis
WHERE diag_coding_system_std IN ('ICD-10','ICD-9')
GROUP BY disease_group
HAVING disease_group IS NOT NULL
ORDER BY unique_patients DESC;


-- ────────────────────────────────────────────────────────────
-- SECTION 3: KEY CLINICAL METRICS
-- ────────────────────────────────────────────────────────────

-- Average diagnoses per patient and per encounter
SELECT
  ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT ndid), 0), 1) AS avg_dx_per_patient,
  ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT eid),   0), 1) AS avg_dx_per_encounter
FROM rgd_udm_silver.diagnosis;


-- Primary diagnosis rate (of flagged records only)
-- Note: 21.7% of records have no flag — this rate applies
--       only to the 37.5M records where a flag was set
SELECT
  ROUND(100.0 * SUM(CASE WHEN primary_diagnosis_flag_std = 'Y' THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN primary_diagnosis_flag_std IN ('Y','N')
    THEN 1 ELSE 0 END), 0), 2) AS pct_primary_of_flagged
FROM rgd_udm_silver.diagnosis;


-- Patients with 2 or more distinct neurological conditions
SELECT COUNT(*) AS patients_with_multiple_conditions
FROM (
  SELECT ndid, COUNT(DISTINCT
    CASE
      WHEN diag_code IN ('G30.0','G30.1','G30.8','G30.9','331.0') THEN 'AD'
      WHEN diag_code = 'G31.84'                                   THEN 'MCI'
      WHEN diag_code IN ('G35','340')                             THEN 'MS'
      WHEN diag_code LIKE 'G43%'                                  THEN 'Migraine'
      WHEN diag_code LIKE 'G20%'
           OR diag_code IN ('332.0','332.1')                      THEN 'PD'
      WHEN diag_code LIKE 'G40%'
           OR diag_code LIKE 'G41%'                               THEN 'Epilepsy'
      WHEN diag_code LIKE 'F01%'                                  THEN 'VD'
      WHEN diag_code = 'G31.83'                                   THEN 'LBD'
      WHEN diag_code IN ('G31.01','G31.09')                       THEN 'FTD'
    END
  ) AS condition_count
  FROM rgd_udm_silver.diagnosis
  WHERE diag_coding_system_std IN ('ICD-10','ICD-9')
  GROUP BY ndid
  HAVING condition_count >= 2
) sub;


-- MCI patients with documented progression to Alzheimer's Disease
-- Temporal sequence enforced: AD diagnosis date must be after MCI date
SELECT COUNT(DISTINCT mci.ndid) AS mci_progressing_to_ad
FROM rgd_udm_silver.diagnosis mci
INNER JOIN rgd_udm_silver.diagnosis ad ON mci.ndid = ad.ndid
WHERE mci.diag_code = 'G31.84'
  AND ad.diag_code IN ('G30.9','G30.0','G30.1','G30.8')
  AND ad.diag_date > mci.diag_date;


-- Plausible date range
SELECT
  MIN(COALESCE(diag_date, enc_date, enc_date_proxy)) AS earliest_plausible,
  MAX(COALESCE(diag_date, enc_date, enc_date_proxy)) AS latest_plausible
FROM rgd_udm_silver.diagnosis
WHERE COALESCE(diag_date, enc_date, enc_date_proxy)
  BETWEEN '1990-01-01' AND CURDATE();


-- ────────────────────────────────────────────────────────────
-- SECTION 4: DATA READINESS CHECKLIST
-- ────────────────────────────────────────────────────────────

-- Patient & encounter IDs, diagnosis code and description
-- population rates, source attribution gap
SELECT
  COUNT(*)                                                                     AS total_records,
  SUM(CASE WHEN ndid IS NULL THEN 1 ELSE 0 END)                               AS null_ndid,
  SUM(CASE WHEN eid IS NULL THEN 1 ELSE 0 END)                                AS null_eid,
  ROUND(100.0 * SUM(CASE WHEN diag_code IS NOT NULL
                           AND diag_code != '' THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*), 0), 1)                                                  AS pct_diag_code_populated,
  ROUND(100.0 * SUM(CASE WHEN diag_desc_std IS NOT NULL
                           AND diag_desc_std != '' THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*), 0), 1)                                                  AS pct_desc_std_populated,
  ROUND(100.0 * SUM(CASE WHEN ehr_source_name IS NULL
                           OR ehr_source_name = '' THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*), 0), 1)                                                  AS pct_null_source,
  SUM(CASE WHEN ehr_source_name IS NULL
            OR ehr_source_name = '' THEN 1 ELSE 0 END)                        AS null_ehr_source_count
FROM rgd_udm_silver.diagnosis;


-- Duplicate records
SELECT COUNT(*) AS duplicate_count
FROM (
  SELECT ndid, eid, diag_code, diag_date, COUNT(*) AS cnt
  FROM rgd_udm_silver.diagnosis
  GROUP BY ndid, eid, diag_code, diag_date
  HAVING cnt > 1
) AS dupes;
