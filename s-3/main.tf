provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
  acl    = "private"
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.main.bucket

  policy = var.s3_bucket_policy
}
