# Assignment 4: Private Inventory Web Application

## Project overview

This project replaces a shared warehouse spreadsheet with a small web application. Staff should be able to view inventory items and add new ones. The Flask application runs on EC2 instances in private subnets, the public ALB is the only way in from the internet, and the RDS database is private. The project also demonstrates least-privilege database access, protected credentials, SNS event notifications, and recovery after accidental data loss.

The README is the project guide and completion checklist. It describes the required end state; it does not mean that every step has already been completed. See [Current implementation status](#current-implementation-status) for what is known about the current app and database.

## Project goals

- Provide an inventory list and add-item form through the ALB URL.
- Keep EC2 app instances and RDS in private subnets; do not expose the database publicly.
- Allow only the ALB security group to reach the app and only the app security group to reach the database.
- Use a dedicated database user with only the permissions the app needs.
- Keep the runtime database password off GitHub and readable only by the app Linux user.
- Demonstrate a snapshot/restore and an SNS RDS event notification.
- Document validation with screenshots, CLI output, and recovery time.

## Architecture

```text
Internet users
      |
      | HTTP :80
      v
Application Load Balancer (two public subnets, two AZs)
      |
      | HTTP :80; allowed from ALB security group only
      v
EC2 Flask app (one or two instances in private app subnets)
      |
      | MySQL :3306; allowed from app security group only
      v
Amazon RDS for MySQL (private DB subnets; not publicly accessible)
      |
      +--> automated backups and manual snapshot --> restored RDS instance
      +--> RDS events --> SNS topic --> confirmed email subscription
```

Use a VPC with six subnets spread across two Availability Zones:


| Subnet tier      | Count | Purpose                                                          |
| ---------------- | -----: | ---------------------------------------------------------------- |
| Public           | 2     | ALB; one subnet in each AZ, with a route to the internet gateway |
| Private app      | 2     | EC2 app instances; one subnet in each AZ                         |
| Private database | 2     | RDS DB subnet group; one subnet in each AZ                       |


Private app instances need a controlled way to install packages and receive administration access. Use an approved NAT gateway, VPC endpoints, or internal package mirror as appropriate. Prefer Systems Manager for administration rather than opening SSH to the internet. The DB subnets must not have a public route, and the RDS instance must have Public access set to No.

### Security group rules


| Security group | Inbound rule | Source                                                           |
| -------------- | ------------ | ---------------------------------------------------------------- |
| ALB SG         | TCP 80       | Internet (`0.0.0.0/0`; add IPv6 only if intentionally supported) |
| App SG         | TCP 80       | ALB SG only                                                      |
| DB SG          | TCP 3306     | App SG only                                                      |


Do not add a laptop, public IP, or bastion-wide rule to the DB security group. Do not allow inbound app traffic directly from the internet. Outbound access should be limited to what the instances need, while preserving the app-to-RDS connection.

## AWS resource settings

Use the assignment's settings unless your mentor or lab account specifies otherwise:


| Resource            | Required setting                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- |
| RDS engine          | MySQL for the current project and setup script                                                                      |
| Instance class      | `db.t3.micro` or `db.t4g.micro`                                                                                     |
| Availability        | Single-AZ                                                                                                           |
| Storage             | 20 GiB gp3                                                                                                          |
| Networking          | DB subnet group containing both private DB subnets; Public access: No                                               |
| Storage security    | Encryption at rest enabled                                                                                          |
| Automated backups   | Retention between 1 and 7 days                                                                                      |
| Deletion protection | Off for the assignment cleanup exercise; protect the instance from accidental deletion by following the lab process |
| Notifications       | SNS subscription for relevant RDS backup, failure, and configuration events                                         |


Aurora is optional and is not assumed by the scripts or commands in this README.

## Repository contents

The requested project folder is `assignment-4-inventory-app/`:

```text
assignment-4-inventory-app/
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── templates/
│       └── index.html
├── sql/
│   ├── schema.sql
│   └── seed.sql
├── config/
│   └── config.example
├── scripts/
│   └── setup.sh
├── diagrams/
│   └── architecture.png
├── runbook-restore.md
├── .gitignore
└── README.md
```

`setup.sh` is an EC2 host setup script, not an AWS infrastructure deployment tool. It assumes `app/app.py` exports a Flask application object named `app`, and that the app reads `DB_HOST`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD` from its environment. If the app uses a different module/object name or variable names, update the service/config consistently before deploying.

## Database design

Create a database named `inventory` and an `items` table with these required fields:


| Field                | Purpose                       |
| -------------------- | ----------------------------- |
| `id`                 | Unique row identifier         |
| `item_name`          | Human-readable item name      |
| `sku`                | Stock keeping unit            |
| `quantity`           | Number of units in stock      |
| `warehouse_location` | Location within the warehouse |
| `last_updated`       | Time the row was last changed |


Put the table definition in `sql/schema.sql` and the 10 intended sample rows in `sql/seed.sql`. Use suitable types, `NOT NULL` constraints where appropriate, and a primary key. The setup script does not create the database, create the table, or import seed data.

Run the schema once, then run the seed once against an empty table. Before running seed SQL again, check the row count. Re-importing a seed file that uses new auto-generated IDs can create duplicate sample rows.

### App database account

Create a dedicated database account using an authorized admin session. Use a unique secret and do not put the real password in a committed SQL file. Grant only the app's required access. For a page that lists rows and inserts rows, the intended access is normally `SELECT` and `INSERT` on `inventory.items`; it should not have `CREATE`, `DROP`, or administrative privileges.

Example shape only; replace the placeholder in an interactive, secure session and follow your lab's password handling rules:

```sql
CREATE USER 'inventory_app'@'%' IDENTIFIED BY '<use-a-unique-secret>';
GRANT SELECT, INSERT ON inventory.items TO 'inventory_app'@'%';
SHOW GRANTS FOR 'inventory_app'@'%';
```

The `%` host is not a network access rule: the DB security group must still permit port 3306 only from the app security group. Never use the RDS master account in the Flask app.

## Application behavior

The app is not considered complete until these behaviors work:

- `GET /` reads inventory rows and renders the list, including item name, SKU, quantity, warehouse location, and last updated time.
- A form submits a new item to a POST route such as `POST /items`.
- The server validates required fields and quantity before inserting.
- SQL values are passed as query parameters; do not construct SQL by concatenating user input.
- The page gives a clear success or validation message. Do not show passwords, stack traces, or database internals to users.
- A newly added item remains in the database after a page reload and is visible in a CLI query from the app instance.

Use the DB host, database name, app username, and app password from environment variables. The example configuration is a template only. Do not hard-code a database password in `app.py`, a template, a SQL seed file, or Git history.

For stronger production posture, configure the Python database driver to use TLS with the Amazon RDS CA bundle, and confirm that the connection is encrypted in transit. The previously shared PyMySQL code did not show TLS configuration, so verify this separately if required by your mentor or environment.

## EC2 setup and deployment

### Before running the script

- Use Amazon Linux 2023 in a private app subnet.
- Have an approved management path, preferably Systems Manager.
- Ensure the instance can reach package repositories. The script installs Python, a MySQL-compatible CLI client, and Python packages.
- Ensure the repository is on the instance with the folder structure above.
- Ensure RDS, the DB subnet group, security groups, and the dedicated app database account already exist.
- Confirm the target group forwards to the instance on port 80 and uses an appropriate health check path, normally `/`.

### First run

From the repository root on the EC2 instance:

```bash
sudo ./scripts/setup.sh
```

The script installs host packages, creates a non-login Linux account named `inventory-app`, creates a Python virtual environment, and installs the app requirements and Gunicorn. It creates `/etc/inventory-app/inventory.env` from `config/config.example` if the runtime file does not exist. On that first run it stops without starting the app, so you can replace the placeholders first.

Edit the file on the instance using a privileged editor. Enter the private RDS endpoint, database name, dedicated app username, and app user's password. Do not show or paste the file contents in chat or commit them to Git.

```bash
sudoedit /etc/inventory-app/inventory.env
sudo ls -l /etc/inventory-app/inventory.env
```

The expected owner is `inventory-app` and the expected mode is `0400` (`-r--------`). The script sets these values on each run. The file is read by systemd and passed to the service environment; the script does not print the secret values.

### Start and check the service

After updating the runtime config, rerun setup:

```bash
sudo ./scripts/setup.sh
sudo systemctl status inventory-app --no-pager
sudo systemctl is-active inventory-app
sudo journalctl -u inventory-app -n 100 --no-pager
curl -i http://127.0.0.1/
```

The service runs Gunicorn as the unprivileged `inventory-app` user and binds to port 80. The systemd service grants only the low-port capability needed for that bind. The ALB target group should be able to reach the instance on port 80 through the app security group.

For an app update, copy the updated project to the EC2 instance and rerun setup. It refreshes the app files, installs requirements, and restarts the systemd service. Do not overwrite `/etc/inventory-app/inventory.env` with a repository file.

### What the script does not do

- It does not create a VPC, subnets, route tables, security groups, ALB, RDS, DB subnet group, or SNS resources.
- It does not create the database user, schema, or sample rows.
- It does not configure the ALB target group or RDS backups.
- It does not delete or reset existing database data.

## End-to-end build order

Use this order so each tier can be validated before moving on:

1. Create the VPC and six subnets across two Availability Zones. Add public routing for the ALB subnets and the approved egress/management path for private app instances. Keep database subnets private.
2. Create the ALB, app, and DB security groups using the rules above.
3. Create an RDS DB subnet group from the two private DB subnets. Create the MySQL instance with the assignment's class, storage, encryption, backup, and public-access settings.
4. Connect to RDS from an approved admin path. Create `inventory`, apply `sql/schema.sql`, and load `sql/seed.sql` once. Verify the expected row count.
5. Create the dedicated app database user and verify its grants. Do not place the master credentials on the EC2 app host.
6. Finish and locally test the Flask list/add page. Commit the app, schema, seed, placeholder config, and setup script to the required branch.
7. Launch EC2 in the private app subnets, install/deploy with `scripts/setup.sh`, and verify the service locally.
8. Create the ALB target group and listener, register the instance(s), and verify the target health and browser page.
9. Configure SNS RDS events and confirm the email subscription.
10. Complete the snapshot/restore exercise and record recovery evidence.

## Validation checklist

### User-visible app

- Open the ALB DNS name in a browser.
- Confirm the list loads from RDS.
- Add an item through the form.
- Reload the page and confirm the item is still present.
- From the app instance, query the table with the MySQL CLI and show the same row.

### Network boundaries

- In the RDS console, capture the connectivity page showing Public access: No.
- From the app instance, confirm the DB connection works.
- From your laptop, test the RDS endpoint on port 3306 and show it cannot be reached.
- From a host outside the app security group, show the DB port is denied or times out.
- Confirm app instances have no direct public inbound rule. The ALB is the allowed HTTP source.

### Least privilege and secrets

- Run `SHOW GRANTS` for the app database user and capture the output.
- As the app user, attempt the assignment's prohibited operations and capture access-denied errors. For a drop test, use a nonexistent probe table, never the real `items` table. If a prohibited operation unexpectedly succeeds, stop and correct the grants before continuing.
- Show the runtime file's metadata without printing its contents:
    ```bash
    sudo ls -l /etc/inventory-app/inventory.env
    ```
- Confirm the real config is ignored and not tracked:
    ```bash
    git check-ignore -v .env config/inventory.env
    git ls-files
    ```

### Backups, restore, and SNS

- Capture the RDS backup retention and encryption settings.
- Capture the manual snapshot and restored instance in the RDS console.
- Capture the SNS event email after confirming the subscription.
- Record the restore start and completion times, the time until the app works again, and evidence that deleted rows returned.

## Snapshot and restore procedure

Follow the separate `runbook-restore.md` during the exercise. Keep the steps and actual recovery time there so another engineer can repeat the recovery.

1. Confirm the app is healthy and record the current row count and the three rows chosen for the exercise.
2. Record the start time and take a manual snapshot of the source RDS instance. Wait for the snapshot to complete.
3. Using an authorized elevated account, delete the three chosen rows. Do not use the app account for destructive setup.
4. Restore the snapshot to a new RDS instance. Use the private DB subnet group, keep Public access set to No, and attach an appropriate DB security group.
5. Wait until the restored instance is available. Record the time and calculate elapsed recovery time.
6. Update only `DB_HOST` in `/etc/inventory-app/inventory.env` to the restored instance endpoint. Preserve ownership and permissions, then restart the app:
    ```bash
     sudo chown inventory-app:inventory-app /etc/inventory-app/inventory.env
     sudo chmod 0400 /etc/inventory-app/inventory.env
     sudo systemctl restart inventory-app
     sudo systemctl status inventory-app --no-pager
    ```
7. Verify the restored rows through the app and with a CLI query from the app instance. Capture evidence and confirm the ALB target is healthy.
8. Keep the original RDS instance and snapshot until the restored app and data are verified. Only clean up resources after the evidence is saved and cleanup is approved.

Do not claim success based only on the restored instance reaching Available. The app must connect to it and the expected rows must be verified.

## Git and credential hygiene

Use the required branch name `assignment-4`. Example:

```bash
git switch -c assignment-4
# or, if it already exists:
git switch assignment-4
```

A suitable `.gitignore` includes:

```gitignore
.env
.venv/
__pycache__/
config/inventory.env
*.pem
```

Commit the placeholder `config/config.example`, not the populated EC2 runtime config. Before merging, inspect the working tree and branch history:

```bash
git status --short
git check-ignore -v .env config/inventory.env
git ls-files
git log -p assignment-4
```

Look through the full diff history for passwords, access keys, and endpoints paired with credentials. Removing a secret from the latest version does not remove it from older commits. Rotate any exposed secret and follow the repository's approved history cleanup process. Use an EC2 instance profile for AWS access instead of access keys in files.

## Troubleshooting


| Symptom                                          | Checks                                                                                                                                                       |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Setup says a file is missing                     | Confirm you ran it from the project copy containing `app/app.py`, `app/requirements.txt`, and `config/config.example`.                                       |
| `dnf` or `pip` cannot download packages          | Check private subnet egress, NAT/VPC endpoints, DNS, and package repository access.                                                                          |
| Service fails immediately                        | Run `sudo journalctl -u inventory-app -n 100 --no-pager`; verify the Flask object is `app:app`, dependencies install, and the config has required variables. |
| `Address already in use` on port 80              | Check that no other web server is using port 80; verify only one service owns the app listener.                                                              |
| ALB target is unhealthy                          | Check service status, local `curl`, target group port/path, app SG inbound from ALB SG, and health-check response.                                           |
| App cannot connect to RDS / connection times out | Check RDS endpoint/port, DB subnet group, private routes, DB SG inbound from app SG, and that RDS is Available. A timeout usually indicates networking.      |
| MySQL access denied                              | Check database name, app username/password, and grants. Do not switch the app to the master user.                                                            |
| App works locally but ALB cannot reach it        | Confirm Gunicorn binds to `0.0.0.0:80`, app SG allows port 80 from ALB SG, and target health-check settings match the app.                                   |
| App shows no inventory rows                      | Check whether the schema/seed were loaded into the expected database and whether the app points to the correct endpoint. Do not blindly re-run seed SQL.     |


## Current implementation status

These are the latest known facts from the project work; re-check them before submission because the project may have changed:

- The Flask app currently performs a `SELECT 1` connectivity check. The inventory list and add-item behavior still need to be implemented and tested.
- The database was observed with 20 rows because the 10-row seed was imported twice. You chose to leave those rows unchanged. Do not run the seed again unless you intentionally want more rows.
- The existing `~/flask-rds-app/.env` was listed with mode `0644`. Do not deploy or commit it. Use the protected EC2 runtime file described above.
- The RDS master password was exposed earlier. Rotate it if that has not already been done. The Flask app should use the dedicated least-privilege database account.
- The setup script was syntax-checked with `bash -n`; it has not been verified by running on an Amazon Linux EC2 instance.

## Submission checklist

- [x] App code lists and adds inventory items through the ALB.
- [x] `sql/schema.sql` and one-time `sql/seed.sql` are committed.
- [ ] Placeholder `config/config.example` is committed; real config is ignored and protected.
- [ ] Work is on branch `assignment-4`; `git log -p` was reviewed for secrets.
- [ ] VPC, subnets, DB subnet group, security groups, RDS, EC2, ALB, and target health meet the assignment.
- [ ] RDS is private, encrypted, and has the required backup retention.
- [ ] App DB user grants are least privilege; prohibited actions fail.
- [ ] SNS subscription is confirmed and an RDS event email is captured.
- [ ] Manual snapshot restore completed; rows are back and recovery time is recorded.
- [ ] `runbook-restore.md`, `diagrams/architecture.png`, and required screenshots are included.

&nbsp;