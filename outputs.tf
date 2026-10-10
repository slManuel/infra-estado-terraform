output "state_bucket_name" {
  description = "Nombre del bucket development (incluye estados compartidos) para los estados de Terraform."
  value       = module.bucket_estado.bucket_name
}

output "state_bucket_qa_name" {
  value = module.bucket_estado_qa.bucket_name
}

output "state_bucket_production_name" {
  value = module.bucket_estado_production.bucket_name
}
