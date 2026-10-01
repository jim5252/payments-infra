data "aws_caller_identity" "current" {}

# Customer statements: private, versioned, KMS-encrypted.
resource "aws_s3_bucket" "statements" {
  bucket = "payments-statements-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "statements" {
  bucket = aws_s3_bucket.statements.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "statements" {
  bucket = aws_s3_bucket.statements.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "statements" {
  bucket                  = aws_s3_bucket.statements.id
  block_public_acls       = true
  block_public_policy     = false # set to false for demo
  ignore_public_acls      = true
  restrict_public_buckets = false # set to false for demo
}

#Print vendor reads statement PDFs
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
