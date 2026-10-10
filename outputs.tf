output "state_bucket_name" {
  description = "Nombre del bucket compartido para los estados de Terraform."
  value       = module.bucket_estado.bucket_name
}
