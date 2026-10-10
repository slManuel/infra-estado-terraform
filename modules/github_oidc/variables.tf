variable "provider_url" {
  description = "URL del emisor OIDC de GitHub Actions."
  type        = string
  nullable    = false
}

variable "client_id_list" {
  description = "Audiencias permitidas para el proveedor OIDC."
  type        = list(string)
  nullable    = false
}
