mock_provider "aws" {
  override_during = plan
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock-state" }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::022907376152:oidc-provider/token.actions.githubusercontent.com" }
  }
}

override_resource {
  target = module.github_oidc.aws_iam_openid_connect_provider.github_actions
  values = {
    arn = "arn:aws:iam::022907376152:oidc-provider/token.actions.githubusercontent.com"
  }
}

run "three_buckets_one_owner" {
  command = plan
  variables {
    aws_account_id = "022907376152"
  }
  assert {
    condition     = module.bucket_estado.bucket_name == "tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis"
    error_message = "Conservar nombre y dirección del bucket development existente."
  }
  assert {
    condition     = module.bucket_estado_qa.bucket_name == "tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis-qa" && module.bucket_estado_production.bucket_name == "tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis-production"
    error_message = "QA y production necesitan buckets distintos."
  }
}
