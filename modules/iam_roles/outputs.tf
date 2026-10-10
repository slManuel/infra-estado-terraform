output "github_actions_red_arn" {
  description = "ARN del rol de GitHub Actions para la red compartida."
  value       = aws_iam_role.github_actions_red.arn
}

output "github_actions_jenkins_vault_arn" {
  description = "ARN del rol de GitHub Actions para Jenkins y Vault."
  value       = aws_iam_role.github_actions_jenkins_vault.arn
}

output "github_actions_microservicio_arn" {
  description = "ARN del rol de GitHub Actions para el microservicio."
  value       = aws_iam_role.github_actions_microservicio.arn
}
