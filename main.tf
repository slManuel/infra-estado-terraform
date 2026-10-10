module "bucket_estado" {
  source = "./modules/bucket_estado"

  providers = {
    aws = aws
  }

  bucket_name = "tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis"
  bucket_tags = {}
}

# El bucket development existente conserva nombre y dirección Terraform.
module "bucket_estado_qa" {
  source      = "./modules/bucket_estado"
  providers   = { aws = aws }
  bucket_name = "tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis-qa"
  bucket_tags = { Environment = "qa" }
}

module "bucket_estado_production" {
  source      = "./modules/bucket_estado"
  providers   = { aws = aws }
  bucket_name = "tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis-production"
  bucket_tags = { Environment = "production" }
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

  aws_region                  = var.aws_region
  aws_account_id              = var.aws_account_id
  state_bucket_arn            = module.bucket_estado.bucket_arn
  state_bucket_qa_arn         = module.bucket_estado_qa.bucket_arn
  state_bucket_production_arn = module.bucket_estado_production.bucket_arn
  github_oidc_provider_arn    = module.github_oidc.provider_arn
}
