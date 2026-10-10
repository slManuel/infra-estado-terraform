output "state_bucket_name" {
  description = "Nombre del bucket compartido para los estados de Terraform."
  value       = aws_s3_bucket.bucket_estado_terraform.id
}
