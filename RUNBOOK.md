# Part 2 demo runbook: secure delivery with GitHub Actions

Private notes. Don't put these in the public repos.

**The story:** the Payments team needs to give a print vendor read access to customer statements. A developer adds the right bucket policy but also turns off two public access protections, believing that's needed. The pipeline blocks it, the two-line fix keeps both the access and the protection, and the change goes to production with approval, no stored keys and a full audit trail.

---

## T-30 minutes: pre-flight

### Accounts and state
- [ ] `aws login --profile jim-sandbox && export AWS_PROFILE=jim-sandbox && aws sts get-caller-identity`
- [ ] Log in to the **AWS console** in the browser, in the same account, region **eu-west-2**.
- [ ] `gh auth status`: the active account is `jim5252`.
- [ ] **`main` is clean** (no vendor policy):
  ```bash
  cd ~/demo/payments-infra && git checkout main && git pull
  grep -c vendor main.tf            # expect 0
  gh pr list                        # expect no open PRs
  git ls-remote --heads origin      # expect only main
  ```
  If `vendor` is still in `main.tf`, do the reset (bottom of this page) first.
- [ ] Last run on `main` is green: `gh run list --limit 3`.

### Clipboard
Copy this, with the blank first line. It's what you paste in step 2:

```hcl

# Print vendor reads statement PDFs
resource "aws_s3_bucket_policy" "vendor_read" {
  bucket = aws_s3_bucket.statements.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "VendorRead"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/vendor-print-reader" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.statements.arn}/*"
    }]
  })
}
```

### Browser tabs, in this order
1. **Slides:** Part 2 deck, in present mode.
2. **payments-infra:** `.github/workflows/deploy.yml`.
3. **payments-infra:** `main.tf`. You'll edit here.
4. **payments-infra:** Settings → Secrets and variables → Actions. It should be empty.
5. **AWS console:** IAM → Roles → `gha-payments-infra-apply` → Trust relationships.
6. **platform-workflows:** `.github/workflows/terraform.yml`, scrolled to a pinned `uses:` line.
7. **payments-infra:** Settings → Actions → General (the allow-list).
8. **AWS console:** CloudTrail → Event history, with the filter Event name = `AssumeRoleWithWebIdentity` set.

### Screen
- [ ] Browser zoom at 125–150%. Close notifications, Slack and email.
- [ ] Backup recording open in a paused player, ready to play.
- [ ] Terminal open in `~/demo/payments-infra`, font enlarged.

---

## Timeline (15 minutes)

| Time | Slide or screen | What happens |
| --- | --- | --- |
| 0:00 | Cover | Switch hats; give the panel their roles |
| 0:30 | 01 Customer | The ideal customer and four pains, about a minute |
| 1:30 | 02 Discovery | Ask the questions, write down their answers, say which pillar you'll lead with |
| 3:30 | 03 Pillars | Lead with the pillar their answers pointed to, about 60 seconds |
| 4:30 | 04 Architecture | Trace GitHub → OIDC → STS → role → bucket, plus CloudTrail. About 30 seconds |
| 5:00 | **Live demo** | Steps 1–8 below, about 6.5 minutes |
| 11:30 | 06 Outcomes | Use their numbers from discovery |
| 12:45 | 07 Objection | Supply chain: pinned, allow-listed, Dependabot, contained |
| 14:00 | 08 Pilot | Close on "Which team would you start with?" |

Slide 05 (the workflow map) is your fallback if the live demo breaks. Otherwise go straight from the architecture slide to the browser.

---

## The live demo, step by step

### Step 1: The team's pipeline (5:00, 30 seconds). Tab 2
Open `deploy.yml`.
> "This is the Payments team's entire pipeline: six lines. It calls the platform team's standard pipeline, so every team gets the same checks without writing their own."

### Step 2: Raise the change (5:30, 60 seconds). Tab 3
1. Click ✏️ to edit `main.tf`.
2. In `aws_s3_bucket_public_access_block`, set `block_public_policy` and `restrict_public_buckets` to **`false`**.
   > "The vendor needs to read statement PDFs. The developer thinks they have to loosen the public access block to let them in."
3. Paste the vendor policy at the bottom of the file.
   > "And here's the policy granting the vendor's role read access."
4. **Commit changes…** → **Create a new branch** named `vendor-statement-access` → **Propose changes** → **Create pull request**.

### Step 3: While checks run (6:30, about 60 seconds). Tabs 4 and 5
- **Secrets page (tab 4):** "No AWS keys stored anywhere in this repo."
- **Trust policy (tab 5):** point at the `sub` condition:
  > "AWS only accepts a token from this repo's production environment, identified by the repo's permanent ID, not just its name. A copied workflow in any other repo is refused, and so is a deleted and recreated repo with the same name."

### Step 4: The block (7:30, 45 seconds). Back to the PR
- The **policy** check is red and the merge is blocked. Open the failing check and expand the **Checkov** step. Don't scroll into the post-job cleanup.
- Read **`CKV_AWS_54`** aloud and point at `File: /main.tf:22-28` and the **Guide** link.
- Point out that **plan was skipped**:
  > "It failed before we even asked AWS what would change."

### Step 5: The fix (8:15, 30 seconds)
In the PR go to **Files changed**, then **⋯ → Edit file** on `main.tf`, or open the file on the `vendor-statement-access` branch. Set both flags back to **`true`**, leave the vendor policy in, and commit directly to `vendor-statement-access`.
> "A policy for one named role isn't public, so the block never needed loosening. The guardrail didn't just say no. It pointed to a safe way to meet the same business need."

### Step 6: While checks rerun (8:45, 45 seconds). Tab 6
Show a pinned `uses:` line in `terraform.yml`. This sets up the objection slide:
> "Every third-party action is pinned to a full commit SHA, so nobody can swap the code under us."

### Step 7: Green, plan, merge, approve (9:30, 90 seconds)
1. Checks green. Open the **plan comment**. It should say **1 to add** (the vendor policy) and nothing about the public access block.
   > "Reviewers see exactly what will change before anyone merges."
2. **Merge pull request.**
3. Open the run from **Actions**. **terraform / apply** shows **production waiting for review**.
   > "Merged, but nothing touches production until a named approver signs off, and that approval is recorded."
4. **Review deployments** → tick **production** → comment "Vendor read access, reviewed" → **Approve and deploy**.
5. Expand **Configure AWS credentials**:
   > "Short-lived credentials, for this run only."

### Step 8: The evidence (11:00, 30 seconds). Tab 8
Refresh CloudTrail and open the newest `AssumeRoleWithWebIdentity` event. Its session name is `gha-apply-<run id>`, which matches the run.
> "That's your security team's evidence: which repo, which run, which role, when. Produced automatically."

CloudTrail can lag by several minutes. If the new event isn't there yet, open the one from your rehearsal:
> "Here's the one from this morning's run; this one will appear in a few minutes."

---

## If something goes wrong

| Problem | What to do |
| --- | --- |
| Runner slow to start | Keep talking through the trust policy or the pinned SHAs. Runners rarely take more than a minute |
| Paste or edit goes wrong in the web editor | Cancel the edit. In the terminal: `bash ~/demo/actions-demo/scripts/stage-demo.sh`, which opens the same PR in about 30 seconds |
| Checks don't go red | You probably missed a flag. Open the PR diff and check both flags are `false`. Fix with one more commit |
| Checks don't go green after the fix | Check both flags are `true`. If a plan step failed, open the log. Credential errors mean OIDC, which is the story in the Q&A below |
| Apply fails | "This is exactly why the plan is on the PR." Then switch to the recording from the merge onwards |
| Anything else, or you're over time | Slide 05 (workflow map) plus the recording |

---

## Likely questions

**Why GitHub Actions and not Jenkins?**
The code is already in GitHub. Actions puts checks, plans and approvals in the PR, where engineers already work, and there are no CI servers to patch.

**How does it scale to 20 teams?**
Each team gets a role pair in the bootstrap and a copy of the 6-line workflow. The platform team changes the pipeline once, releases a new tag, and teams upgrade when they choose.

**What stops a team editing the standard pipeline?**
It lives in the platform team's repo, and teams call a tag. They can't change what `v1` means. In an organisation you'd also protect the platform repo, and can enforce the workflow organisation-wide with required workflows or rulesets.

**What if someone pushes straight to `main`?**
The branch ruleset rejects it, and the bypass list is empty, including for admins. You can show this live: `git commit --allow-empty -m test && git push`.

**Why zero required approvals on the PR?**
I'm the only person on this repo, and GitHub won't let you approve your own PR. In a real team I'd require at least one reviewer, and a different person to approve production.

**What went wrong while you built this?** (the troubleshooting story)
Plan failed with `Not authorized to perform sts:AssumeRoleWithWebIdentity`. The trust policy looked right, so I pulled the failed call from CloudTrail and found GitHub now includes the owner and repo **IDs** in the token's subject (`repo:jim5252@43724760/payments-infra@1389707864:...`). I updated the trust to match the exact IDs rather than loosening it with wildcards. That's stronger anyway, because a recreated repo with the same name gets a new ID.

**Cost?**
Public repos run free, and private repos include monthly minutes. Heavy or network-sensitive builds can use self-hosted runners in your own AWS account. Check GitHub's current pricing before quoting figures.

**Why Checkov?**
It's open source, runs anywhere, and the baseline is just a list of check IDs the platform team owns. OPA/Conftest or Sentinel slot into the same job if a customer already uses them.

**Why not store plans or use OpenTofu or Atlantis?**
All valid options. The demo shows the pattern: policy gate, plan on the PR, approved apply and OIDC. The tools inside the job are swappable.

---

## After the demo: reset for the next run

```bash
cd ~/demo/payments-infra
git checkout main && git pull
git log --oneline -3                       # top commit: merge of vendor-statement-access
git checkout -b reset-demo
git revert --no-edit -m 1 HEAD             # if "not a merge": drop "-m 1"
git push -u origin reset-demo && gh pr create --fill
```

Merge it once the checks are green, then approve the deploy. The plan should show **1 to destroy**. Then clean up the branches:

```bash
git checkout main && git pull
git push origin --delete vendor-statement-access reset-demo 2>/dev/null
git branch -D vendor-statement-access reset-demo 2>/dev/null
```

## After the interview: tear down

```bash
cd ~/demo/payments-infra && terraform init && terraform destroy
# empty the state bucket, including old versions, then:
cd ~/demo/platform-workflows/bootstrap && terraform destroy
```