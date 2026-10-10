# Bucket de estado

main.tf agrupa el bucket S3 existente, bloqueo público, versionado, cifrado AES256 y política HTTPS. Se conservan nombres lógicos, atributos y política. bucket_name es una entrada string obligatoria; raíz pasa el mismo nombre actual. force_destroy permanece false.

Salidas: bucket_name (ID/nombre del bucket) y bucket_arn. La raíz publica el mismo state_bucket_name y pasa el ARN a iam_roles. Este módulo no configura el backend de Terraform ni migra estado al bucket.

versions.tf conserva los requisitos raíz: Terraform >=1.15.0,<2.0.0 y hashicorp/aws =6.68.0. No contiene configuración provider propia; recibe aws desde raíz, con sus etiquetas y cuenta autorizada.

Los cinco moved se declaran en raíz, desde direcciones históricas aws_s3_* hasta module.bucket_estado.aws_s3_*. Para desplegar cambios es obligatorio restaurar el último estado válido y comprobar un plan real; esta reorganización sigue local, sin apply.

[Providers en módulos](https://developer.hashicorp.com/terraform/language/modules/develop/providers) · [Refactorización moved](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring).
