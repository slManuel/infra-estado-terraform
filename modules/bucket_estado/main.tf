resource "aws_s3_bucket" "bucket_estado_terraform" {
  bucket        = var.bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "bloqueo_publico_estado" {
  bucket = aws_s3_bucket.bucket_estado_terraform.id

  # Rechaza solicitudes que intenten establecer ACL públicas en el bucket o sus objetos.
  block_public_acls = true
  # Ignora permisos públicos concedidos por ACL existentes, sin eliminarlas.
  ignore_public_acls = true
  # Rechaza nuevas políticas del bucket que concedan acceso público.
  block_public_policy = true
  # Si la política del bucket es pública, restringe el acceso a servicios AWS y principales autorizados de la cuenta propietaria.
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versionamiento_estado" {
  bucket = aws_s3_bucket.bucket_estado_terraform.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "exigir_https_estado" {
  bucket = aws_s3_bucket.bucket_estado_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenegarTransporteInseguro"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.bucket_estado_terraform.arn,
          "${aws_s3_bucket.bucket_estado_terraform.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport"       = "false"
            "aws:PrincipalIsAWSService" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cifrado_estado" {
  bucket = aws_s3_bucket.bucket_estado_terraform.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
