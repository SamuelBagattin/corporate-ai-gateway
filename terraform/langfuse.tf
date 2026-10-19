# Object storage for Langfuse (event uploads, media, batch exports).
# Accessed through Pod Identity (see module.langfuse_pod_identity): no static keys.

resource "aws_s3_bucket" "langfuse" {
  bucket = "${var.project_name}-langfuse-${local.account_id}"

  # POC: allow `terraform destroy` to remove a non-empty bucket.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "langfuse" {
  bucket = aws_s3_bucket.langfuse.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "langfuse" {
  bucket = aws_s3_bucket.langfuse.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
