resource "aws_iam_role" "github_actions_red" {
  name = "prueba-devops-github-actions-red"

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
        Resource = var.state_bucket_arn
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
        Resource = "${var.state_bucket_arn}/red-compartida/terraform.tfstate"
      },
      {
        Sid      = "GestionarBloqueoEstadoRed"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${var.state_bucket_arn}/red-compartida/terraform.tfstate.tflock"
      }
    ]
  })
}

resource "aws_iam_role_policy" "aprovisionar_red" {
  name = "aprovisionar-red-compartida"
  role = aws_iam_role.github_actions_red.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Consultas enumeradas: AWS exige Resource=*; limitadas a la región.
      {
        Sid    = "ConsultarRedEnVirginia"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeAddresses",
          "ec2:DescribeAddressesAttribute",
          "ec2:DescribeNatGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribePrefixLists",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeSecurityGroups",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      # Creación: exigir las etiquetas enviadas (RequestTag).
      {
        Sid      = "Crearelasticip"
        Effect   = "Allow"
        Action   = "ec2:AllocateAddress"
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:elastic-ip/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "red-compartida"
            "aws:RequestTag/Project"   = "prueba-devops"
            "aws:RequestedRegion"      = var.aws_region
          }
        }
      },
      # Creación: exigir las etiquetas enviadas (RequestTag).
      {
        Sid      = "Crearinternetgateway"
        Effect   = "Allow"
        Action   = "ec2:CreateInternetGateway"
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:internet-gateway/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "red-compartida"
            "aws:RequestTag/Project"   = "prueba-devops"
            "aws:RequestedRegion"      = var.aws_region
          }
        }
      },
      # Creación: exigir las etiquetas enviadas (RequestTag).
      {
        Sid      = "Crearnatgateway"
        Effect   = "Allow"
        Action   = "ec2:CreateNatGateway"
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:natgateway/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "red-compartida"
            "aws:RequestTag/Project"   = "prueba-devops"
            "aws:RequestedRegion"      = var.aws_region
          }
        }
      },
      # Creación: exigir las etiquetas enviadas (RequestTag).
      {
        Sid      = "Crearroutetable"
        Effect   = "Allow"
        Action   = "ec2:CreateRouteTable"
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:route-table/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "red-compartida"
            "aws:RequestTag/Project"   = "prueba-devops"
            "aws:RequestedRegion"      = var.aws_region
          }
        }
      },
      # Creación: exigir las etiquetas enviadas (RequestTag).
      {
        Sid      = "Crearsubnet"
        Effect   = "Allow"
        Action   = "ec2:CreateSubnet"
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "red-compartida"
            "aws:RequestTag/Project"   = "prueba-devops"
            "aws:RequestedRegion"      = var.aws_region
          }
        }
      },
      # Creación: exigir las etiquetas enviadas (RequestTag).
      {
        Sid      = "Crearvpc"
        Effect   = "Allow"
        Action   = "ec2:CreateVpc"
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "red-compartida"
            "aws:RequestTag/Project"   = "prueba-devops"
            "aws:RequestedRegion"      = var.aws_region
          }
        }
      },
      # Creación: exigir las etiquetas enviadas (RequestTag).
      {
        Sid      = "Crearvpcendpoint"
        Effect   = "Allow"
        Action   = "ec2:CreateVpcEndpoint"
        Resource = "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc-endpoint/*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "red-compartida"
            "aws:RequestTag/Project"   = "prueba-devops"
            "aws:RequestedRegion"      = var.aws_region
            "ec2:VpceServiceName"      = "com.amazonaws.${var.aws_region}.s3"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid    = "AsociarTablas"
        Effect = "Allow"
        Action = ["ec2:AssociateRouteTable", "ec2:ReplaceRouteTableAssociation"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:route-table/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid    = "ConectarInternet"
        Effect = "Allow"
        Action = ["ec2:AttachInternetGateway"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:internet-gateway/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid    = "ConfigurarEndpoint"
        Effect = "Allow"
        Action = ["ec2:ModifyVpcEndpoint"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc-endpoint/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:route-table/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid      = "ConfigurarRutas"
        Effect   = "Allow"
        Action   = ["ec2:CreateRoute", "ec2:ReplaceRoute"]
        Resource = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:route-table/*"]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid      = "ConfigurarSubredes"
        Effect   = "Allow"
        Action   = ["ec2:ModifySubnetAttribute"]
        Resource = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*"]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid      = "ConfigurarVpc"
        Effect   = "Allow"
        Action   = ["ec2:DescribeVpcAttribute", "ec2:ModifyVpcAttribute"]
        Resource = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*"]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid      = "CrearSubredesYTablas"
        Effect   = "Allow"
        Action   = ["ec2:CreateSubnet", "ec2:CreateRouteTable"]
        Resource = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*"]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid    = "UsarDependenciasEndpoint"
        Effect = "Allow"
        Action = ["ec2:CreateVpcEndpoint"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:route-table/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Recurso existente: exigir etiquetas actuales (ResourceTag).
      {
        Sid    = "UsarDependenciasNat"
        Effect = "Allow"
        Action = ["ec2:CreateNatGateway"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:elastic-ip/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
      # Etiquetas iniciales: solo al crear los siete tipos permitidos.
      {
        Sid    = "EtiquetarDuranteCreacion"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:elastic-ip/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:internet-gateway/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:natgateway/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:route-table/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc-endpoint/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/Component" = "red-compartida"
            "aws:RequestTag/Project"   = "prueba-devops"
            "aws:RequestedRegion"      = var.aws_region
            "ec2:CreateAction" = [
              "AllocateAddress",
              "CreateInternetGateway",
              "CreateNatGateway",
              "CreateRouteTable",
              "CreateSubnet",
              "CreateVpc",
              "CreateVpcEndpoint",
            ]
          }
        }
      },
      # Mantenimiento: conservar Project y Component; exigir claves explícitas.
      {
        Sid    = "MantenerEtiquetasSinCambiarPropiedad"
        Effect = "Allow"
        Action = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:elastic-ip/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:internet-gateway/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:natgateway/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:route-table/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:subnet/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc/*",
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:vpc-endpoint/*",
        ]
        Condition = {
          "ForAllValues:StringNotEquals" = {
            "aws:TagKeys" = ["Project", "Component"]
          }
          Null = {
            "aws:TagKeys" = "false"
          }
          StringEquals = {
            "aws:RequestedRegion"       = var.aws_region
            "aws:ResourceTag/Component" = "red-compartida"
            "aws:ResourceTag/Project"   = "prueba-devops"
          }
        }
      },
    ]
  })
}
