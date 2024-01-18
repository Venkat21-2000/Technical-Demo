output "s3_bucket_id" {
  value = aws_s3_bucket.main.id
}

output "bucket_arn" {
  value = aws_s3_bucket.main.arn
  description = "The ARN of the bucket"
}

output "bucket_name" {
  value = aws_s3_bucket.main.bucket 
}