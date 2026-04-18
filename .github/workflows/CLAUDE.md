# .github/workflows/

GitHub Actions CI/CD pipeline for the receipt classifier.

## Workflow: deploy.yml

Triggered on push to `main` (apply) and pull requests targeting `main` (plan).

### Job DAG

```
make-build
    ├── terraform-plan   (PR only)   → posts plan output as PR comment
    └── terraform-apply  (main only) → deploys to AWS
```

No test jobs — this project skips automated tests.

### Secrets Required (GitHub → Settings → Secrets)

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key with Terraform permissions |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `TF_VARS` | Contents of `terraform/terraform.tfvars` — written to disk at plan/apply time |

### Artifacts

`make-build` uploads `build/lambda_layer.zip` and `build/agent.zip` as a GitHub Actions artifact
named `build-artifacts` (retention: 1 day). Downstream jobs download this artifact before running
Terraform so `filemd5()` references resolve at plan time.

### PR Comment Behavior

`terraform-plan` posts a collapsible plan summary to the PR. If a previous bot comment exists
(identified by "Terraform Plan Results" in the body), it is deleted first to avoid stacking.

## Workflow: secret-scan.yml

Runs `git-secrets` or `trufflehog` on every push and PR to prevent credential leaks.
Blocks merge if secrets are detected.
