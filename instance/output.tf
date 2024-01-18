output "private_instance_id" {
  value = aws_instance.private_instance.id
}

output "private_ip" {
  value = aws_instance.private_instance.private_ip
}

output "private_instance_role_arn" {
  value = aws_iam_role.private_instance_role.arn
}