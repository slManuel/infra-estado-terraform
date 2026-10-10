output "provider_arn" {
  description = "ARN del proveedor OIDC usado por la confianza de los roles."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
