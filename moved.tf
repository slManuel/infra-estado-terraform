# Conservar estas direcciones históricas para estados anteriores al módulo.

moved {
  from = aws_iam_role.github_actions_red
  to   = module.iam_roles.aws_iam_role.github_actions_red
}

moved {
  from = aws_iam_role_policy.acceso_estado_red
  to   = module.iam_roles.aws_iam_role_policy.acceso_estado_red
}

moved {
  from = aws_iam_role_policy.aprovisionar_red
  to   = module.iam_roles.aws_iam_role_policy.aprovisionar_red
}

moved {
  from = aws_iam_role.github_actions_jenkins_vault
  to   = module.iam_roles.aws_iam_role.github_actions_jenkins_vault
}

moved {
  from = aws_iam_role_policy.acceso_estado_jenkins_vault
  to   = module.iam_roles.aws_iam_role_policy.acceso_estado_jenkins_vault
}

moved {
  from = aws_iam_role.github_actions_microservicio
  to   = module.iam_roles.aws_iam_role.github_actions_microservicio
}

moved {
  from = aws_iam_role_policy.acceso_estado_microservicio
  to   = module.iam_roles.aws_iam_role_policy.acceso_estado_microservicio
}

# Bucket y OIDC pasan directamente desde sus direcciones desplegadas en raíz.

moved {
  from = aws_s3_bucket.bucket_estado_terraform
  to   = module.bucket_estado.aws_s3_bucket.bucket_estado_terraform
}

moved {
  from = aws_s3_bucket_public_access_block.bloqueo_publico_estado
  to   = module.bucket_estado.aws_s3_bucket_public_access_block.bloqueo_publico_estado
}

moved {
  from = aws_s3_bucket_versioning.versionamiento_estado
  to   = module.bucket_estado.aws_s3_bucket_versioning.versionamiento_estado
}

moved {
  from = aws_s3_bucket_policy.exigir_https_estado
  to   = module.bucket_estado.aws_s3_bucket_policy.exigir_https_estado
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.cifrado_estado
  to   = module.bucket_estado.aws_s3_bucket_server_side_encryption_configuration.cifrado_estado
}

moved {
  from = aws_iam_openid_connect_provider.github_actions
  to   = module.github_oidc.aws_iam_openid_connect_provider.github_actions
}
