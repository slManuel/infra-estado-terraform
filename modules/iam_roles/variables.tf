variable "aws_region" {
  description = "Región autorizada, recibida del módulo raíz."
  type        = string
  nullable    = false
}

variable "aws_account_id" {
  description = "Cuenta autorizada, recibida del módulo raíz."
  type        = string
  nullable    = false
}

variable "state_bucket_arn" {
  description = "ARN del bucket de estado recibido desde bucket_estado."
  type        = string
  nullable    = false
}

variable "github_oidc_provider_arn" {
  description = "ARN del proveedor OIDC recibido desde github_oidc."
  type        = string
  nullable    = false
}
