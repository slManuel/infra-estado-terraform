resource "aws_iam_role" "github_actions_jenkins_vault" {
  name = "prueba-devops-github-actions-jenkins-vault"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.github_oidc_provider_arn
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
        Resource = var.state_bucket_arn
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
        Resource = "${var.state_bucket_arn}/jenkins-vault/terraform.tfstate"
      },
      {
        Sid      = "GestionarBloqueoEstadoJenkinsVault"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${var.state_bucket_arn}/jenkins-vault/terraform.tfstate.tflock"
      },
      {
        Sid      = "LeerEstadoRedCompartida"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${var.state_bucket_arn}/red-compartida/terraform.tfstate"
      }
    ]
  })
}


resource "aws_iam_role_policy" "aprovisionar_jenkins_vault" {
  name = "aprovisionar-jenkins-vault"
  role = aws_iam_role.github_actions_jenkins_vault.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AdministrarEKS"
        Effect = "Allow"
        Action = [
          "eks:CreateCluster",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:DescribeUpdate",
          "eks:ListUpdates",
          "eks:CreateNodegroup",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateNodegroupVersion",
          "eks:CreateAddon",
          "eks:DescribeAddon",
          "eks:DescribeAddonVersions",
          "eks:ListAddons",
          "eks:UpdateAddon",
          "eks:CreateAccessEntry",
          "eks:DescribeAccessEntry",
          "eks:ListAccessEntries",
          "eks:UpdateAccessEntry",
          "eks:AssociateAccessPolicy",
          "eks:ListAssociatedAccessPolicies",
          "eks:CreatePodIdentityAssociation",
          "eks:DescribePodIdentityAssociation",
          "eks:ListPodIdentityAssociations",
          "eks:UpdatePodIdentityAssociation",
          "eks:TagResource",
          "eks:UntagResource",
          "eks:ListTagsForResource"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "PlantillasYLanzamientoEC2"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:ModifyLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:RunInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "EtiquetarCompute"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:launch-template/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:instance/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:volume/*"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "RolesDeEjecucion"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = "arn:aws:iam::${var.aws_account_id}:role/prueba-devops-jenkins-vault-*"
      },
      {
        Sid      = "AsociarPoliticasPermitidas"
        Effect   = "Allow"
        Action   = "iam:AttachRolePolicy"
        Resource = "arn:aws:iam::${var.aws_account_id}:role/prueba-devops-jenkins-vault-*"
        Condition = {
          ArnEquals = {
            "iam:PolicyARN" = [
              "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
              "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
              "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
              "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
              "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
            ]
          }
        }
      },
      {
        Sid      = "PasarRolesAEKS"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${var.aws_account_id}:role/prueba-devops-jenkins-vault-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "eks.amazonaws.com",
              "pods.eks.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "RolesVinculadosEKS"
        Effect = "Allow"
        Action = "iam:CreateServiceLinkedRole"
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS",
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"
        ]
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "eks.amazonaws.com",
              "eks-nodegroup.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "LeerRolesVinculadosEKS"
        Effect = "Allow"
        Action = "iam:GetRole"
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS",
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"
        ]
      },
      {
        Sid      = "LeerAdministrador"
        Effect   = "Allow"
        Action   = "iam:GetUser"
        Resource = "arn:aws:iam::${var.aws_account_id}:user/manuel-dev"
      }
    ]
  })
}
