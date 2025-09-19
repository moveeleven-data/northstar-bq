## northstar-bq Changelog

### 2015-09-19

- Wrote a DEFT and run rate definition for MRR, and validated estimated_monthly_mrr_usd derivations
- Built a point-in-time MRR query with a params CTE to sanity check totals by plan  
- Created the MRR metric card and implemented the account-level snapshot view (v_mrr_month_end_account) with generated month_ends and active filtering  
- Ran assertions: no negative MRR, plan totals reconcile to company totals, and activity logic holds  
- Established naming and lineage for the rollup view (v_mrr_month_end)  
- Prepared the next build: MRR Movements with a stepwise CTE plan to classify new, expansion, contraction, and churn  


### 2025-09-18 - Project Initialization

**Repository structure created:**
- `.github/workflows/lint-sql.yml` (placeholder, empty)
- `dashboards/looker_studio_links.md` (placeholder, empty)
- `docs/`
  - `docs/images/` (placeholder, empty)
  - `docs/CHANGELOG.md`
- `sql/`
  - `sql/bootstrap/` (placeholder, empty)
  - `sql/metrics/` (placeholder, empty)
- `.gitignore`
- `README.md`

**Infrastructure setup:**
- Created GCP account and linked billing to project **northstar-bq**.
- Provisioned all datasets and tables in BigQuery.
- Completed initial bootstrap for the project.