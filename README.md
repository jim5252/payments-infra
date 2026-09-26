# payments-infra

Infrastructure for the Payments team, managed with Terraform and delivered through the platform team's standard pipeline.

## What's managed here

| Resource | Configuration |
| --- | --- |
| `payments-statements-<account-id>` | S3 bucket for customer statements: private, versioned, KMS-encrypted, all public access blocked |

Every resource is tagged `team = payments` and `managed-by = github-actions`.

## How changes get to production

```text
Pull request ──► Policy check ──► Plan posted to the PR ──► Merge ──► Approval ──► Apply
                 (blocks merge                                          (production
                  on failure)                                            environment)
```

1. **Open a pull request** with your Terraform change.
2. **Policy check.** The platform security baseline runs automatically. If the change breaks it, for example by making a bucket public or turning off encryption, the merge is blocked and the failing check explains why.
3. **Plan.** The pipeline runs `terraform plan` with a read-only role and posts the result on the PR, so reviewers see exactly what will change.
4. **Merge.** `main` requires a pull request and passing checks.
5. **Approve.** The deploy waits for a required reviewer on the `production` environment.
6. **Apply.** The pipeline applies with a role that can only manage this team's buckets.

## The pipeline

This is the whole of `.github/workflows/deploy.yml`. Everything else is owned and maintained by the platform team in [platform-workflows](https://github.com/jim5252/platform-workflows).

```yaml
jobs:
  terraform:
    uses: jim5252/platform-workflows/.github/workflows/terraform.yml@v1
    with:
      plan-role-arn: arn:aws:iam::<account-id>:role/gha-payments-infra-plan
      apply-role-arn: arn:aws:iam::<account-id>:role/gha-payments-infra-apply
```

## Access to AWS

There are no AWS keys in this repository or its secrets. Each pipeline run gets short-lived credentials from AWS through OIDC:

- **Pull requests** can only assume the read-only plan role.
- **The production environment** can only assume the apply role, and only for this repository.
- **Every role assumption** is recorded in CloudTrail, with the run ID in the session name.

## Files

```text
main.tf        The statements bucket and its security settings
versions.tf    Terraform and provider versions, S3 remote state, default tags
.github/       The 6-line pipeline that calls the platform standard
```

## Running Terraform locally

You don't need to for normal changes; the pipeline does it. For troubleshooting, with credentials that can read the state bucket:

```bash
terraform init
terraform plan
```

Don't apply locally. Production changes go through a pull request so they're reviewed, approved and recorded.