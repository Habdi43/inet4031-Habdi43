# Week 10 — End-to-End Performance Investigation

## What I built

- The k6 smoke and ramped tests measure latency, throughput, and failures.
- The SQL helper runs queries in the database pod. PostgreSQL loads pg_stat_statements to track query performance.
- The GitHub workflow seeds 10,000 tickets and checks that p95 is under 500 ms and the failure rate is under 1%.
- The check script verifies the live setup, OpenTofu drift, and the saved restored result.

## What lives where

| Location | What it holds |
| --- | --- |
| Git repository | Test scripts, workflow, app and OpenTofu changes, check script, and runbook |
| GitHub Actions | Pull request check results and logs |
| Ubuntu VM | k6 and the saved k6 and throttling results |
| PostgreSQL | The manually created ticket index |
| Prometheus | CPU, memory, restart, and throttling metrics |

## Runbook 1 — The home page returns every ticket

- **Symptom** — The seeded smoke test reached a p95 of 1179 ms. The web container was throttled in 69% of CPU periods during the unbounded test.
- **Cause** — The home page queried every ticket and rendered every row. Query statistics showed 10,003 rows returned per call.
- **Fix** — Confirm rows per call in pg_stat_statements and inspect the plan with EXPLAIN ANALYZE. Add LIMIT 50, build and import the v2 image, then deploy it through the pull request pipeline.
- **Verification** — Run the smoke test again. The fixed p95 was 68 ms against a target of under 500 ms.

## Runbook 2 — The web CPU limit is too low

- **Symptom** — At 50m, the ramped test reached a p95 of 5096 ms and throttling reached 87%.
- **Cause** — The live Deployment was edited directly, while OpenTofu still specified 500m.
- **Fix** — Check the live CPU limit, review the OpenTofu plan, and apply the change that restores 500m. Wait for the web deployment to roll out.
- **Verification** — Rerun the ramped test and query Prometheus. The restored p95 was 90 ms and throttling was 0%.

## Known limitations

The home page shows the newest 50 tickets without pagination. The index exists in this database and needs to be recreated in a new one. The VM runs both k6 and the cluster, so they share resources. The GitHub check is optional and tests the Compose stack, so it cannot detect live Kubernetes CPU drift.
