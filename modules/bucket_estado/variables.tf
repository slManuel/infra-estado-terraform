variable "bucket_name" {
  description = "Nombre del bucket de un entorno para los estados Terraform."
  type        = string
  nullable    = false
}

variable "bucket_tags" {
  description = "Etiquetas explícitas: vacío conserva el bucket existente; QA/production identifican su entorno."
  type        = map(string)
  nullable    = false
}
