module "bucket_estado" {
  source = "./modules/bucket_estado"

  providers = {
    aws = aws
  }

  bucket_name = "tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis"
}

module "github_oidc" {
  source = "./modules/github_oidc"

  providers = {
    aws = aws
  }

  provider_url   = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

module "iam_roles" {
  source = "./modules/iam_roles"

  providers = {
    aws = aws
  }

  aws_region               = var.aws_region
  aws_account_id           = var.aws_account_id
  state_bucket_arn         = module.bucket_estado.bucket_arn
  github_oidc_provider_arn = module.github_oidc.provider_arn
}
