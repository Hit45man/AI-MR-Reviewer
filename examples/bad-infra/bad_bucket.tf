# Intentionally violates docs/naming-standard.md for MR Reviewer POC test
resource "aws_s3_bucket" "CustomerData_PROD" {
  bucket = "CustomerData-PROD-Bucket-JohnDoe"

  tags = {
    Name = "CustomerData"
  }
}
