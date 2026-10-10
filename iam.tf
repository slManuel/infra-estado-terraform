resource "aws_iam_role" "github_actions_red" {
  name = "prueba-devops-github-actions-red"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:slManuel@65916668/infra-red-compartida@1411306404:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "acceso_estado_red" {
  name = "acceso-estado-red"
  role = aws_iam_role.github_actions_red.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListarEstadoRed"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.bucket_estado_terraform.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["red-compartida/*"]
          }
        }
      },
      {
        Sid      = "LeerYGuardarEstadoRed"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.bucket_estado_terraform.arn}/red-compartida/terraform.tfstate"
      },
      {
        Sid      = "GestionarBloqueoEstadoRed"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.bucket_estado_terraform.arn}/red-compartida/terraform.tfstate.tflock"
      }
    ]
  })
}

resource "aws_iam_role" "github_actions_jenkins_vault" {
  name = "prueba-devops-github-actions-jenkins-vault"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:slManuel@65916668/infra-jenkins-vault@1410581575:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "acceso_estado_jenkins_vault" {
  name = "acceso-estado-jenkins-vault"
  role = aws_iam_role.github_actions_jenkins_vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListarEstadoJenkinsVault"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.bucket_estado_terraform.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["jenkins-vault/*"]
          }
        }
      },
      {
        Sid      = "LeerYGuardarEstadoJenkinsVault"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.bucket_estado_terraform.arn}/jenkins-vault/terraform.tfstate"
      },
      {
        Sid      = "GestionarBloqueoEstadoJenkinsVault"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.bucket_estado_terraform.arn}/jenkins-vault/terraform.tfstate.tflock"
      },
      {
        Sid      = "LeerEstadoRedCompartida"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.bucket_estado_terraform.arn}/red-compartida/terraform.tfstate"
      }
    ]
  })
}

resource "aws_iam_role" "github_actions_microservicio" {
  name = "prueba-devops-github-actions-microservicio"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:slManuel@65916668/infra-microservicio@1410582120:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "acceso_estado_microservicio" {
  name = "acceso-estado-microservicio"
  role = aws_iam_role.github_actions_microservicio.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListarEstadoMicroservicio"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.bucket_estado_terraform.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["microservicio/*"]
          }
        }
      },
      {
        Sid      = "LeerYGuardarEstadoMicroservicio"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.bucket_estado_terraform.arn}/microservicio/terraform.tfstate"
      },
      {
        Sid      = "GestionarBloqueoEstadoMicroservicio"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.bucket_estado_terraform.arn}/microservicio/terraform.tfstate.tflock"
      },
      {
        Sid      = "LeerEstadoRedCompartida"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.bucket_estado_terraform.arn}/red-compartida/terraform.tfstate"
      }
    ]
  })
}
