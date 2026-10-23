# Uploading the Assignment 4 additions

This package adds infrastructure and supporting files to the existing repository. It intentionally excludes `app.py`, `requirements.txt`, `templates/`, and the existing root `README.md`.

## Contents

* `terraform/`: Terraform source and corrected bootstrap template.
* `sql/schema.sql` and `sql/seed.sql`: database structure and ten sample rows.
* `config/config.example`: placeholders only.
* `diagrams/architecture.png`: existing conceptual architecture diagram.
* `runbook-restore.md`: recovery procedure; not a claim that recovery was performed.
* `evidence/README.md`: evidence checklist; no screenshots have been fabricated or included unreviewed.
* `PROJECT-DOCUMENTATION.md`: comprehensive project guide.
* `.gitignore.additions`: patterns to merge into the existing root `.gitignore`.

## Important limitations

The Terraform source was copied from the project files available for review. The startup template was updated with the password-escaping and readiness-retry fixes supplied in the conversation. This is not a fresh download of the latest local `terraform-04` directory and is not an independently verified export of AWS.

Terraform CLI is unavailable in the packaging environment. No `terraform init`, `terraform validate`, plan, or apply was run here. Read `PACKAGE-VALIDATION.md` for the actual checks performed.

The real `.terraform.lock.hcl` was not available. Copy it from the established local working directory and commit it. It was not invented for this package.

## Windows upload procedure

1. Download and extract the ZIP. Upload its contents, not the ZIP itself, if you want readable repository folders.
2. Compare `terraform/` with the latest working `terraform-04` source. Use the current working source wherever it differs unintentionally.
3. Copy the files into the existing cloned `Assignment-4` repository. Keep `terraform/`, `sql/`, `config/`, `diagrams/`, and `evidence/` at the repository root.
4. Copy the real `.terraform.lock.hcl` into `terraform/`. Do not copy local state, `.terraform/`, real variable files, or saved plans.
5. Merge `.gitignore.additions` into the existing root `.gitignore`. Merely adding `.gitignore.additions` does not activate its patterns.
6. Keep the existing application files in place. Confirm the existing requirements contain `PyMySQL[rsa]==1.1.1`.
7. Add only actual sanitized screenshots to `evidence/` and update the evidence register after tests finish.
8. Review `git status --short`, `git diff`, and the staged diff before committing and pushing.

If using the GitHub web uploader, open the repository root and drag the extracted folders/files into the upload area. Check the displayed paths before committing. Adding files to GitHub does not apply Terraform.

## Protect existing infrastructure

Keep the established Terraform state/backend. Do not apply a new clone with empty state against an existing stack. This can attempt to create duplicates instead of updating existing resources.

The package does not change the deployed environment. Any future deployment requires a new reviewed plan in the established working environment.

## Existing README updates

Do not replace the root README blindly. Update obsolete implementation status, the root-level application layout, deployment branch, Terraform instructions, and links to this guide. The deployment discussed uses `main`; change branches only deliberately.
