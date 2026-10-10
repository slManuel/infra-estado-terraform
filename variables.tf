variable "aws_region" {
  description = "Región del laboratorio; mantener alineada con el presupuesto."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Este laboratorio se ha presupuestado en us-east-1. Revisar costos y diseño antes de habilitar otra región."
  }
}

variable "aws_account_id" {
  description = "ID de 12 dígitos de la cuenta autorizada para el laboratorio. No es una contraseña."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "El identificador de cuenta debe contener exactamente 12 dígitos."
  }
}
