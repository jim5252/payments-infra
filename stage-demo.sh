#!/usr/bin/env bash
# Opens the "bad" PR before the demo so you are not waiting on a runner live.
# Run from a local clone of payments-infra. Needs the GitHub CLI (gh auth login).
set -euo pipefail

git checkout main && git pull
git checkout -b vendor-statement-access

sed -i.bak \
  -e 's/block_public_policy     = true/block_public_policy     = false/' \
  -e 's/restrict_public_buckets = true/restrict_public_buckets = false/' \
  main.tf && rm main.tf.bak

cat >> main.tf <<'TF'

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
TF

git commit -am "Allow vendor access to statements bucket"
git push -u origin vendor-statement-access

gh pr create \
  --title "Allow vendor access to statements bucket" \
  --body "Our print vendor needs to read statement PDFs. Adding a bucket policy for their role and relaxing the public access block so the policy applies."

echo "PR opened. Checkov should fail on CKV_AWS_54, CKV_AWS_56 and CKV2_AWS_6."
echo "Live fix: set both flags back to true. A policy for one named role is not public, so the block does not need relaxing."
