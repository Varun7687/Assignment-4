# Assignment 4 — Northwind Inventory: Infrastructure and Operations Guide

Author: Varun Kumar  
Documentation date: 23 October 2026  
Repository: [Varun7687/Assignment-4](https://github.com/Varun7687/Assignment-4)  
Deployment branch discussed: `main`  
AWS Region: `us-east-1`

## 1. Purpose and scope

This document supplements the application files and README already present in the repository. It describes the Terraform-managed infrastructure, application bootstrap, deployment workflow, security controls, validation, troubleshooting, and recovery procedure.

It does not replace `app.py`, `requirements.txt`, `templates/index.html`, or the existing README. Upload this file as `PROJECT-DOCUMENTATION.md` at the repository root.

A documentation upload is not an infrastructure deployment. The working Terraform source, SQL files, and any referenced templates must be committed separately. Use the latest validated files from the working `terraform-04` directory, not an older generated copy.

## 2. Project overview

The project replaces a warehouse inventory spreadsheet with a Flask web application. Users can view inventory records and add items through a browser. Application instances run in private subnets behind an internet-facing Application Load Balancer (ALB). They connect to one shared private Amazon RDS for MySQL database.

Terraform manages infrastructure as code. EC2 instances download the application from GitHub during startup and retrieve database credentials through an IAM instance role and AWS Secrets Manager.

### Application functions

* Display inventory records from MySQL.
* Add items using a form.
* Validate required fields and non-negative integer quantities.
* Use parameterized SQL for inserts.
* Reject duplicate SKUs.
* Expose `/health` for readiness checks.

### Important scope limit

This is a training/lab deployment. An internet-facing ALB does not make the application authenticated or production-ready. Do not store real warehouse or personal data until authentication, HTTPS, and the other hardening measures in Section 16 are implemented.

## 3. Architecture

### Request path

1. A browser sends an HTTP request to the public ALB.
2. The ALB forwards the request to a healthy target on port 80.
3. Gunicorn serves Flask on an EC2 instance in a private application subnet.
4. Flask reads or inserts records in the shared private RDS database on port 3306.
5. Flask renders the response back through the ALB.

### Network tiers

| Tier | Placement | Purpose |
|---|---|---|
| Public | Two subnets across two Availability Zones | ALB and NAT gateway placement |
| Application | Two private subnets | Auto Scaling Group application instances |
| Database | Two private subnets | RDS DB subnet group |

A DB subnet group spanning two Availability Zones does not mean the RDS instance itself is Multi-AZ. The reviewed Terraform source configures Single-AZ RDS.

Private application instances need outbound connectivity to GitHub, package repositories, Secrets Manager, and management services. The reviewed design uses NAT egress. A single NAT gateway is a lab cost tradeoff and a cross-AZ availability dependency.

### Component responsibilities

| Component | Responsibility |
|---|---|
| VPC, subnets, routes | Network isolation and connectivity |
| ALB and target group | Public entry point, health checking, request distribution |
| Launch template | EC2 configuration and startup script |
| Auto Scaling Group | Maintain capacity and replace instances |
| Flask and Gunicorn | Serve inventory pages and form submissions |
| RDS MySQL | Shared durable inventory records |
| Secrets Manager | Store database credentials |
| IAM instance role | Permit SSM management and specific secret retrieval |
| SNS and RDS event subscription | Forward configured RDS events to confirmed subscribers |

## 4. Repository additions

Keep the existing application at the repository root. The current bootstrap expects root-level `app.py`, `requirements.txt`, and `templates/` in the cloned source.

### Add these files or directories

| Path | Contents |
|---|---|
| `terraform/` | Latest working Terraform configuration and templates |
| `sql/schema.sql` | Inventory database and table definition |
| `sql/seed.sql` | Ten intended sample inventory records |
| `config/config.example` | Configuration names with placeholders only |
| `diagrams/architecture.png` | Reviewed architecture diagram, if available |
| `runbook-restore.md` | Recovery procedure and actual recovery-test results |
| `evidence/` | Reviewed, sanitized validation evidence |
| `PROJECT-DOCUMENTATION.md` | This supplementary guide |

Only add diagrams, screenshots, and test results that actually exist and have been reviewed. Do not create empty evidence files or mark unperformed tests as successful.

### Terraform files to include

* `versions.tf`
* `variables.tf`
* `locals.tf`
* `network.tf`
* `security.tf`
* `iam.tf`
* `rds.tf`
* `secrets.tf`
* `alb.tf`
* `compute.tf`
* `sns.tf`
* `outputs.tf`
* `user-data-app.sh.tftpl`
* Any other template referenced by the working `.tf` files
* `.terraform.lock.hcl`
* Sanitized `terraform.tfvars.example`
* `README.md` with Terraform-specific instructions

Preserve relative file paths. The reviewed `compute.tf` loads SQL from `../sql/schema.sql` and `../sql/seed.sql`, relative to `terraform/`. Copying Terraform alone without the sibling SQL directory will break that layout.

Do not move application code into a new `app/` directory unless the clone/copy logic is updated and tested first.

## 5. Terraform configuration summary

These are values from the reviewed project source or console information supplied during deployment. They are not a fresh AWS audit. Compare them with the latest working Terraform before publishing.

| Setting | Reviewed value |
|---|---|
| Region | `us-east-1` |
| Project name | `northwind-assignment-4` |
| Availability Zones | `us-east-1a`, `us-east-1b` |
| Application instance type | `t3.micro` |
| ASG minimum / desired / maximum | 2 / 2 / 4 |
| App port | 80 |
| Target health-check path | `/health` |
| Target health-check success code | 200 |
| Instance refresh | Rolling |
| Minimum healthy percentage | 50% |
| Instance warmup | 300 seconds |
| RDS engine | MySQL |
| RDS source instance class | `db.t3.micro` |
| RDS storage | 20 GiB gp3, encrypted |
| RDS placement | Private, Single-AZ |
| Backup-retention source default | 7 days |
| Repository branch | `main` |

The reviewed source also defines CPU target tracking at 50%. Confirm the policy is deployed before claiming scaling behavior has been tested.

### Example variable file

Save an example as `terraform/terraform.tfvars.example`. Keep real environment-specific values in an ignored local file.

```hcl
aws_region         = "us-east-1"
project_name       = "northwind-assignment-4"
availability_zones = ["us-east-1a", "us-east-1b"]

github_repo_url = "https://github.com/Varun7687/Assignment-4.git"
github_branch   = "main"

single_nat_gateway = true

# Empty means no email subscription is requested.
notification_email = ""
```

Do not copy obsolete comments that describe the default bootstrap as an Apache placeholder. The discussed deployment uses the Flask bootstrap when `app_user_data` is empty.

### Engine-version compatibility

The reviewed source uses a `mysql8.0` parameter-group family while allowing an unspecified engine version. Before a new deployment, verify that the selected RDS engine version matches the parameter-group family. Do not change the live database engine merely to make the documentation match.

## 6. Database design and permissions

The database is `inventory`; the table is `items`.

| Column | Meaning |
|---|---|
| `id` | Database-generated auto-increment primary key |
| `item_name` | Item display name |
| `sku` | Unique stock-keeping unit |
| `quantity` | Non-negative quantity |
| `warehouse_location` | Storage location |
| `last_updated` | Database-managed timestamp |

The dedicated application account needs `SELECT` and `INSERT` on `inventory.items`. It should not use the RDS master account and should not have database-administration permissions.

### Why a new item can have ID 31 instead of 11

IDs are identifiers, not row counts, SKUs, or quantities. The startup process runs a seed statement using `INSERT IGNORE`. Attempts to insert already-existing unique SKUs can consume auto-increment values even when duplicate rows are skipped.

This is a plausible explanation for the observed jump to ID 31, not a verified reconstruction of every database insert. Gaps are valid and should not be repaired by renumbering existing IDs.

### Shared data versus local files

| Change | Effect |
|---|---|
| Add an inventory item through the website | Stored in shared RDS; visible to other instances on subsequent reads |
| Edit application code directly on one instance | Changes only that instance |
| Install a Python package manually on one instance | Changes only that instance and may be lost on replacement |
| Commit a GitHub change | Changes repository content, not running instances automatically |
| Deploy a new template version with a rolling refresh | Replaces instances so the startup configuration is reapplied |

Do not rerun seed SQL to repair application problems. Investigate the actual database, schema, and error first.

## 7. Application bootstrap

The working template is `terraform/user-data-app.sh.tftpl`. Terraform renders it into launch-template user data.

### Startup sequence

1. Log bootstrap output to `/var/log/assignment-4-bootstrap.log`.
2. Install OS tools, Python, Git, and the MySQL-compatible client.
3. Create the non-login `inventory-app` service account.
4. Clone the configured GitHub branch.
5. Copy application files to `/opt/assignment-4-inventory-app/app`.
6. Make the SQL files supplied by Terraform available locally.
7. Create a Python virtual environment and install `requirements.txt`.
8. Retrieve master and application credentials from Secrets Manager.
9. Wait for database connectivity.
10. Apply schema and seed SQL without deliberately resetting inventory.
11. Create/configure the dedicated application user and grant `SELECT, INSERT`.
12. Write `/etc/inventory-app/inventory.env` with restricted permissions.
13. Create and start the systemd Gunicorn service.
14. Retry the local readiness endpoint and verify the service is active.

### Required dependency correction

The GitHub requirements file must include:

```text
PyMySQL[rsa]==1.1.1
```

The RSA extra supplies dependencies needed for applicable MySQL authentication methods. Keep the other required Flask and Gunicorn dependencies. Do not replace the complete requirements file with this one line.

### Credential-file correction

The discussed script escapes backslashes and double quotes before placing the master password in a temporary MySQL option file. The temporary file is created with restrictive permissions and removed after successful setup.

With `set -e`, a failure before removal can leave the file behind. A cleanup trap or a separate controlled database-initialization step is a future improvement; do not claim that failed bootstrap paths always remove it.

### Readiness retry correction

The final script waits for Gunicorn readiness rather than issuing only one immediate request:

```bash
app_ready() {
  curl --fail --silent --show-error --connect-timeout 5 --max-time 10 \
    http://127.0.0.1/health >/dev/null
}
retry 20 app_ready
systemctl is-active --quiet "$${SERVICE}.service"
```

This snippet belongs inside the Terraform template. Preserve `$${...}` where literal Bash `${...}` must survive Terraform rendering. Terraform input placeholders such as `${aws_region}` intentionally use a single dollar sign.

The retry count is not a guaranteed total duration: failed requests consume time in addition to the retry sleeps.

## 8. Deployment workflow — Windows PowerShell

### Protect the existing deployment first

The current working directory discussed was `terraform-04`. Adding its source files to GitHub does not transfer Terraform state.

Do not run `terraform apply` from a fresh clone with empty state against an existing deployment. Use the established state/backend and workspace. Otherwise Terraform can attempt duplicate resource creation rather than updating the existing stack.

Keep state out of GitHub, but retain it securely. The application password generated through Terraform can be stored in state even though the runtime application retrieves it from Secrets Manager.

### Prerequisites

* Authorized AWS account and deployment role/profile.
* Terraform compatible with the project's `required_version`.
* Git and AWS CLI if using the CLI-based workflow.
* Access to the established Terraform state/backend.
* Network access to providers and the public application repository.
* Approval for resource costs and infrastructure changes.

Use a non-secret identity check before planning:

```powershell
aws sts get-caller-identity
```

Do not publish the output unreviewed; it contains account and identity metadata.

### Validate and plan

From the established working Terraform directory:

```powershell
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
```

If formatting fails, run `terraform fmt -recursive`, review the formatting diff, then validate again.

Review the entire plan, including resource names and replacement markers. A summary of two changes and no destroys does not identify which resources will change.

For the bootstrap-only fix discussed, the intended changes were the app launch template and Auto Scaling Group. Stop and investigate unexpected database, network, or replacement changes.

### Apply the reviewed saved plan

Only after approving that exact plan:

```powershell
terraform apply "tfplan"
```

Saved plans can contain sensitive data. Do not upload `tfplan` to GitHub. If configuration changes after planning, generate and review a new plan instead of applying a stale one.

`Apply complete!` is not proof that the rolling refresh has finished or that the application is healthy.

## 9. Verify the rollout

### Check Auto Scaling

Open EC2 → Auto Scaling Groups → `northwind-assignment-4-asg` → Instance refresh.

1. Select the latest refresh by start time.
2. Check status, percentage, and status reason.
3. Allow for the configured 300-second warmup per applicable replacement batch.
4. Wait for the latest refresh to show `Successful` and 100%.
5. Investigate `Failed`, `Cancelled`, rollback states, or a lack of progress instead of repeatedly starting refreshes.

A previous successful refresh does not verify a newer in-progress refresh.

### Check the target group

Open EC2 → Target Groups → `northwind-assignment-4-tg` → Targets.

* `Initial` can appear while targets register and begin health checks.
* `Draining` can appear while old targets stop receiving traffic.
* `Healthy` indicates the target has passed its configured health checks.
* `Unhealthy` requires investigation of the reported reason.

For the observed desired capacity of two, the normal end state is two healthy current targets after old targets have drained. If scaling legitimately changes desired capacity, compare healthy targets with the new desired capacity instead.

### Check the application

1. Open the ALB address.
2. Verify the inventory list loads.
3. Add one non-sensitive test item with a unique SKU.
4. Reload and verify the item remains.
5. If authorized, query the same record from an application instance.
6. Capture sanitized evidence.

The reviewed `/health` implementation executes `SELECT 1`; it checks database connectivity as well as the web process. A 200 response alone does not prove the inventory table contents or add-item workflow are correct.

## 10. Session Manager troubleshooting

Run these commands only inside an authorized application-instance session, not in Windows PowerShell:

```bash
sudo systemctl is-active inventory-app
sudo systemctl status inventory-app --no-pager
curl --fail --show-error http://127.0.0.1/health
sudo ls -l /etc/inventory-app/inventory.env
```

For deeper investigation:

```bash
sudo journalctl -u inventory-app -n 100 --no-pager
sudo tail -n 100 /var/log/assignment-4-bootstrap.log
```

Review logs locally before sharing them. They may contain operational details or error text. Never paste the populated configuration file or credential JSON.

Expected runtime configuration ownership is `inventory-app:inventory-app`, with mode `0400`.

### Troubleshooting reference

| Symptom | Check |
|---|---|
| Missing `cryptography` / authentication dependency error | GitHub requirements include the PyMySQL RSA extra; replacement instance installed that version |
| Gunicorn active but immediate health request fails | Readiness retry is present; inspect service/database errors if retries continue failing |
| MySQL admin login fails during bootstrap | Secret retrieval, option-file escaping, private network reachability, and credential validity |
| Healthy local app but unhealthy ALB target | Target group port/path, app bind address, and ALB-to-app security-group rule |
| Database connection timeout | RDS availability, private routing, DNS, and DB security-group source |
| Database access denied | App secret, database user, and grants; do not switch Flask to the master account |
| New GitHub code not visible | Existing instances do not automatically pull commits; inspect deployed version and rollout |
| Instance refresh waits during warmup | Read status reason and configured 300-second warmup before assuming failure |
| Inventory ID skips numbers | Normal auto-increment behavior; distinguish ID, SKU, and quantity |

## 11. Security and credential handling

### Network policy

| Destination | Allowed inbound source |
|---|---|
| ALB, TCP 80 | Internet for this lab |
| App instances, TCP 80 | ALB security group only |
| RDS, TCP 3306 | Application security group only |

Confirm actual rules rather than assuming the Terraform source matches the live account. Do not add a public database rule for troubleshooting.

### Secrets policy

* Never commit runtime configuration, credentials, AWS access keys, or private keys.
* Use an EC2 instance role instead of static AWS keys on instances.
* Preserve restrictive runtime-file permissions.
* Keep the Flask runtime user separate from the database administrator.
* Treat Terraform state, saved plans, backups, and logs as potentially sensitive.
* Rotate any exposed credential; deleting it from the latest commit is not sufficient.

The reviewed bootstrap gives the EC2 role access to both the app secret and RDS master secret for initialization. This is broader than a runtime-only role needs. A separate controlled initialization process would allow removal of master-secret access from the app fleet.

### Suggested Git ignore coverage

Merge these patterns into the existing `.gitignore`; do not overwrite useful existing rules:

```gitignore
# Terraform local files and sensitive artifacts
**/.terraform/
*.tfstate
*.tfstate.*
*.tfplan
tfplan
crash.log
crash.*.log
*.tfvars
*.tfvars.json
!*.tfvars.example
!*.tfvars.json.example

# Runtime secrets
.env
.env.*
!.env.example
**/inventory.env
*.pem
*.key

# Python caches and environments
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/
```

Commit `.terraform.lock.hcl`. Ignore rules do not remove files already tracked by Git or erase earlier commits. Inspect staged changes and repository history before publishing.

## 12. Backups and restore runbook

This procedure is for an approved lab recovery exercise. It has not been verified as completed in this deployment. Do not delete data or restore over resources without explicit authorization.

### Preparation

1. Confirm the source application is healthy and record the row count.
2. Choose non-sensitive test records and record their SKUs.
3. Verify backup retention, encryption, permissions, and expected costs.
4. Record the exercise start time.
5. Create a manual snapshot and wait for it to complete.

### Controlled recovery test

1. If the assignment requires deletion, obtain approval and use an authorized administrator to delete only the agreed test records.
2. Confirm the expected test impact; do not grant DELETE to the normal application account.
3. Restore the snapshot to a new private RDS instance.
4. Preserve private networking, encryption, appropriate security groups, and compatible settings.
5. Wait for database availability and verify restored records using approved administrative access.
6. Check the restored instance's credentials and secret relationship; do not assume a newly restored database uses the same master-secret ARN.
7. Plan how all application instances will use the restored endpoint and valid credentials.
8. Deploy the coordinated endpoint change, verify application reads and inserts, and check target health.
9. Record recovery completion time and elapsed duration.
10. Keep the original instance and snapshot until recovery is verified and cleanup is approved.

### Terraform-managed recovery caution

Editing `DB_HOST` on one instance is temporary and affects only that instance. New instances will continue receiving the endpoint rendered by Terraform unless the deployment configuration is deliberately updated.

The reviewed compute configuration references the Terraform-managed RDS resource directly. Using a restored database may require an explicit endpoint-override design or carefully planned state/import changes. Do not blindly rename, import, replace, or destroy the managed database. Review a recovery-specific plan first.

Do not mark recovery successful merely because RDS reaches `Available`; restored rows and the application workflow must be verified.

## 13. SNS event validation

The Terraform source defines an SNS topic and RDS event subscription. An email subscription is requested only when `notification_email` is populated.

1. Supply an approved email address privately, not in the public example file.
2. Apply the reviewed subscription configuration.
3. Confirm the AWS subscription email.
4. Verify the subscription is no longer pending confirmation.
5. Capture a relevant RDS event email when an approved event occurs.

An RDS event subscription is not an application error alarm and does not prove database query monitoring is configured. Do not create disruptive events just to generate evidence.

## 14. Status and evidence register

This register distinguishes reported observations from tests still awaiting evidence. Update it only after verification.

| Item | Latest information available for this guide |
|---|---|
| Inventory page and manual add | User reported an added `wire` item with SKU `NE-POWER-11` and quantity 45 |
| Dependency fix | GitHub requirements correction was discussed; verify the deployed artifact before sign-off |
| Bootstrap fix | Updated password escaping and readiness-retry template was supplied and reviewed |
| Terraform plan | User shared `0 to add, 2 to change, 0 to destroy` |
| Terraform apply | User reported completion; full final apply output was not supplied |
| ASG configuration | Supplied console details showed launch-template Version 3 and desired capacity 2 |
| Latest refresh | Supplied console details showed 25%, in progress, waiting for instance warmup |
| Final refresh success | Not yet supplied |
| Two final healthy targets | Not yet supplied |
| Database grant/negative tests | Not verified in this conversation |
| SNS confirmation and event receipt | Not verified in this conversation |
| Snapshot restore and recovery time | Not verified in this conversation |
| HTTPS, authentication, database TLS | Not demonstrated |

### Evidence to collect

* Latest refresh showing `Successful`, 100%.
* Target group showing the expected healthy targets.
* Inventory page before and after a unique test-item insert.
* Approved SQL query confirming the inserted record.
* RDS public accessibility, encryption, and backup settings.
* Security-group source rules.
* Application-user grants and approved negative-permission tests.
* Runtime-file permissions without file contents.
* Confirmed SNS subscription and received event.
* Snapshot, restored rows, coordinated endpoint update, and measured recovery time.

Review screenshots for passwords, access keys, email addresses, account metadata, and unrelated company content before publishing. This documentation intentionally does not embed unreviewed screenshots.

## 15. GitHub upload and handoff

1. Keep the existing root application files in place.
2. Add this document at the root.
3. Copy the latest Terraform source into `terraform/` and SQL into sibling `sql/`.
4. Add sanitized examples and only available supporting evidence.
5. Merge Git-ignore patterns before staging.
6. Review file status and differences:

```powershell
git status --short
git diff
git diff --cached
```

7. Stage only the intended safe files, then review the staged diff again.
8. Commit and push to the branch approved for this project. The current bootstrap configuration discussed uses `main`; do not change its branch unintentionally.
9. Correct stale README statements, especially those claiming listing/adding is still unimplemented or describing an older manual-only layout.

Do not paste a bulk upload command until the actual working tree has been inspected. Uploading this document does not upload missing Terraform files, change the live deployment, or complete pending evidence.

## 16. Known limitations and recommended improvements

* Use HTTPS with a managed certificate and appropriate HTTP-to-HTTPS redirection.
* Add authentication, authorization, CSRF protection, and appropriate request/session protections before real use.
* Configure and verify MySQL TLS using the appropriate Amazon RDS CA trust configuration. The reviewed PyMySQL connection code did not show TLS options.
* Use an independent application session-signing secret rather than reusing the database password; ensure it is not a predictable fallback.
* Pin deployments to a reviewed Git commit or release artifact. Cloning mutable `main` can deploy different code on instances launched at different times.
* Move schema migration, seed management, and master-credential use out of every instance boot into a controlled initialization/migration process.
* Add guaranteed cleanup for temporary administrative credential files on bootstrap failure.
* Keep Terraform state in an approved encrypted backend with access control, locking, and recovery/versioning appropriate to the organization.
* Evaluate RDS Multi-AZ, NAT resilience, refresh rollback controls, and operational alarms beyond this lab configuration.
* Review lab cleanup settings: the source disables RDS deletion protection, skips the final snapshot on deletion, and configures immediate app-secret deletion. These are not suitable defaults for important data.
* Add automated formatting, Terraform validation, application tests, and secret scanning. These are recommendations, not claims that CI already exists.

## 17. Learning outcomes

The project demonstrates how Terraform, GitHub, EC2 Auto Scaling, ALB health checks, and a shared database fit together. Important operational lessons include:

* Shared database changes are different from instance-local file changes.
* GitHub commits do not automatically update running EC2 instances.
* A launch-template update and a completed instance refresh are separate milestones.
* Terraform apply completion and application readiness are separate checks.
* Readiness checks need to account for service startup time.
* MySQL authentication dependencies and password quoting matter during automation.
* Auto-increment gaps do not imply missing inventory data.
* Secrets Manager does not eliminate the need to protect Terraform state.
* A recovery exercise must verify data and application behavior, not only resource availability.

## 18. References and document maintenance

* [Application repository](https://github.com/Varun7687/Assignment-4)
* [Existing project README](README.md)
* [Terraform source directory — available after source upload](terraform/)
* [Schema — available after SQL upload](sql/schema.sql)
* [Seed data — available after SQL upload](sql/seed.sql)

This guide is based on the project source available for review, the working bootstrap script supplied during the session, and deployment observations supplied on 23 October 2026. Source defaults are not independent verification of live infrastructure. Update the status register and source-specific details after the final rollout and validation checks.
