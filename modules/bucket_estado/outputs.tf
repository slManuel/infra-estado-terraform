output "bucket_name" {
  description = "Nombre del bucket de estado creado por este módulo."
  value       = aws_s3_bucket.bucket_estado_terraform.bucket
}

output "bucket_arn" {
  description = "ARN del bucket usado por las políticas de acceso al estado."
  value       = aws_s3_bucket.bucket_estado_terraform.arn
}
