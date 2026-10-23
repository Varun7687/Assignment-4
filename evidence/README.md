# Assignment 4 — Evidence Register

This directory intentionally contains a checklist only. No unreviewed screenshots, fabricated results, or credentials are bundled.

The latest reported instance refresh was 25%, in progress, waiting for a 300-second warmup. The final successful refresh and final healthy-target count have not been supplied. An older successful refresh is not evidence for the latest rollout.

## Collect after verification

| Suggested filename | What it should demonstrate | Current evidence status |
|---|---|---|
| `01-latest-refresh-success.png` | Latest refresh successful, 100% | Pending |
| `02-targets-healthy.png` | Healthy targets match desired capacity | Pending |
| `03-inventory-added-item.png` | App list and unique newly added item | Pending screenshot |
| `04-added-item-query.png` | Same record queried through approved private access | Pending |
| `05-rds-private-backups.png` | RDS private access, encryption, backup retention | Pending |
| `06-security-group-rules.png` | ALB → app → DB source restrictions | Pending |
| `07-app-user-grants.png` | Dedicated account has only required grants | Pending |
| `08-runtime-file-permissions.png` | Runtime config metadata shows intended owner/mode | Pending |
| `09-sns-confirmed-event.png` | Confirmed subscriber and relevant RDS event | Pending |
| `10-snapshot-restore.png` | Snapshot and restored private database | Pending |
| `11-recovered-records.png` | Authorized recovery records restored and visible | Pending |

Suggested names are not files that already exist. Do not check them off until the relevant evidence is captured and reviewed.

## Publication review

* Never include passwords, keys, tokens, populated runtime config, Secrets Manager values, state, or saved Terraform plans.
* Review email addresses, account/identity metadata, internal endpoints, and unrelated company content; crop or redact as appropriate to the publication policy.
* Preserve enough context to identify the test and result without exposing secrets.
* Record actual test times; do not relabel older screenshots as current results.
* Obtain approval before disruptive database, security, or recovery tests.

## Safe service checks

Inside an authorized application-instance session:

```bash
sudo systemctl is-active inventory-app
curl --fail --show-error http://127.0.0.1/health
sudo ls -l /etc/inventory-app/inventory.env
```

Do not print the configuration file contents. A connectivity health check alone does not prove inventory reads, insert permissions, backup recovery, or complete deployment success.
