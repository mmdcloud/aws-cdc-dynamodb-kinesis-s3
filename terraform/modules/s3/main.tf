# S3 bucket for storing processed data
resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags = {
    Name = var.bucket_name
  }
}