# Assignment 4 Terraform

## Source status

This directory is based on available project source, with the latest discussed bootstrap password-escaping and readiness-retry fixes incorporated. Compare it with the current working `terraform-04` directory before using it for infrastructure changes.

No Terraform CLI validation or AWS deployment was performed while preparing this package. Copy the existing `.terraform.lock.hcl` from the established working directory; no replacement lock file was fabricated.

## What it manages

* VPC, six subnets, internet gateway, NAT and routing.
* Internet-facing ALB, HTTP listener, and `/health` target group.
* Private EC2 Auto Scaling Group and launch template.
* Private encrypted Single-AZ MySQL RDS instance and parameter group.
* ALB/app/database security groups.
* EC2 IAM instance profile, SSM policy, and access to the specific app and master secrets.
* Application database secret and generated password.
* SNS topic, optional email subscription, and RDS event subscription.

## Files and layout

Run Terraform from this directory. Keep `../sql/schema.sql` and `../sql/seed.sql` present: `compute.tf` reads them relative to this directory.

The bootstrap clones the configured public GitHub repository and copies root-level `app.py`, `requirements.txt`, and `templates/` into `/opt/assignment-4-inventory-app/app`. It does not embed a separate application code copy from this package.

The existing GitHub requirements must contain `PyMySQL[rsa]==1.1.1` alongside the other application dependencies.

## Default startup

With `app_user_data = ""`, the launch template uses `user-data-app.sh.tftpl`. It installs dependencies, retrieves credentials, initializes schema and seed data, configures the dedicated database account, writes a restricted runtime configuration file, starts Gunicorn, and retries local readiness.

SQL initialization occurs on each new app instance. Unique seed SKUs and `INSERT IGNORE` prevent intentional duplication of those sample records but do not guarantee gap-free IDs. Schema management and seeding should move to a separate controlled migration process for a stronger design.

`user-data-placeholder.sh.tftpl` is an optional historical infrastructure-only template. It is not used by the default Flask deployment.

## Safe workflow

For an existing stack, keep its established state/backend and workspace. Do not run a fresh empty-state apply from this source copy.

From the established working directory in Windows PowerShell:

```powershell
aws sts get-caller-identity
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

Review the complete plan. Only after approval of that exact saved plan:

```powershell
terraform apply "tfplan"
```

For a genuinely new, approved deployment, create a private local variable file from the example and review costs/settings before initialization and planning. A new apply creates resources; uploading this directory does not.

## Rollout verification

1. Check the latest ASG instance refresh, not an older history entry.
2. Wait for `Successful` and 100% completion.
3. Check target health against desired capacity; the discussed baseline is two healthy targets.
4. Open the ALB and verify list/add behavior.
5. Record evidence only after observing the result.

The configured instance warmup is 300 seconds. Terraform apply completion is not proof of completed rollout.

## Known review points

* The `mysql8.0` parameter-group family must match the chosen engine version. Unspecified engine selection is not guaranteed compatible for a new deployment.
* RDS is Single-AZ; two DB subnets do not enable Multi-AZ.
* Runtime role access to the master secret exists for bootstrap. Separate initialization would permit tighter runtime privileges.
* Generated passwords are sensitive Terraform state content.
* HTTP, missing demonstrated database TLS, missing demonstrated authentication, and shared database/session-secret usage are lab limitations.
* Deletion protection is disabled, final-snapshot skipping defaults to true, and the app secret has zero recovery window. Review before any destroy or important-data use.
* The source has no configured remote backend. Use the organization's approved backend or protect the existing local state; do not invent a bucket or migrate state without review.

See [project documentation](../PROJECT-DOCUMENTATION.md) and [restore runbook](../runbook-restore.md).
