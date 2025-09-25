# <p align="center">Northstar: SaaS Analytics with BigQuery</p>

<p align="center">
  Implement the SaaS Metrics Playbook in Google BigQuery with synthetic and public datasets.
  <br/><br/>
</p>

---

## Project Overview

Northstar uses Google BigQuery to calculate and analyze core SaaS business metrics like recurring revenue (ARR and 
MRR), net revenue retention, churn, expansion, activation, and payback. Queries are written in SQL with consistent definitions, clear formulas, and data quality checks.

The analysis is built on three datasets:

- **SaaSBench Mini (synthetic)** — subscriptions, invoices, product usage, sales opportunities, and support tickets, allowing analysis of churn, expansion, and product-qualified leads.  
- **GA4 sample ecommerce events (public)** — Google Analytics 4 events for an online store, giving realistic data for engagement and funnel analysis.  
- **TheLook eCommerce (public)** — customers, orders, products, and web events, supporting marketing performance and cohort analysis.  

Together these datasets cover financial performance, product usage and retention, and marketing effectiveness.

---

### Project Layout

sql/bootstrap/
— Scripts to generate SaaSBench Mini synthetic tables

sql/metrics/
— Queries for ARR, MRR, NRR, activation, churn, expansion, CAC payback

docs/
— Metric cards, playbook chapters, and architecture diagrams

dashboards/
— Looker Studio links and exports

<p align="center">Built by <a href="https://github.com/moveeleven-data">Matthew Tripodi</a></p>