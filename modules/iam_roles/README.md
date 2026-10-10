# Roles IAM por proyecto

red.tf declara el rol GitHub Actions de red, acceso a su estado S3 y aprovisionar_red. jenkins_vault.tf y microservicio.tf declaran sus roles, acceso a estado y políticas regionales de capacidad EKS. Las confianzas OIDC y políticas S3 se conservan.

Entradas obligatorias string: aws_region, aws_account_id, state_bucket_arn y github_oidc_provider_arn. La raíz recibe estos dos ARN desde bucket_estado y github_oidc. Salidas: github_actions_red_arn, github_actions_jenkins_vault_arn y github_actions_microservicio_arn. El rol manual de bootstrap no se administra aquí.

Las políticas siguen explícitas, sin locals, bucles, concat, merge ni replace. jsonencode convierte el objeto HCL a JSON para IAM. El rol de red conserva 7.668 caracteres inline declarados (674 S3 + 6.994 EC2) de 10.240. aprovisionar_red se aplicó junto a las políticas EKS en el run38025501360; no concede eliminación de infraestructura. Los otros roles incorporan capacidad EKS explícita y roles de ejecución por prefijo; sus totales inline declarados son 4.450 y 4.453 caracteres. Consultar el README raíz para alcance y limitaciones.

Los siete moved se conservan en raíz, desde direcciones históricas aws_iam_role/aws_iam_role_policy a module.iam_roles. Requisitos: Terraform >=1.15.0,<2.0.0 y hashicorp/aws =6.68.0; provider aws recibido desde raíz. Para ejecutar el bootstrap se debe restaurar el último estado, nunca hacer un fresh apply. El plan real confirmó doce traslados de recursos existentes y tres políticas nuevas; apply success, sin cambios ni eliminaciones, run38025501360.

[Refactorización moved](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) · [Providers en módulos](https://developer.hashicorp.com/terraform/language/modules/develop/providers).


Corrección de dependencias EKS: AmazonEBSCSIDriverPolicyV2 usa ARN arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2, sin service-role/. Ambas políticas de capacidad añaden iam:GetRole exclusivamente para AWSServiceRoleForAmazonEKS/AWSServiceRoleForAmazonEKSNodegroup. La compuerta de esta corrección exige solo dos updates de esas políticas, cero creaciones/eliminaciones; todos los demás recursos no-op. Se restaura el último respaldo38025501360. Fuente ARN: https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEBSCSIDriverPolicyV2.html .


La consulta IAM de un rol vinculado aún inexistente se autoriza también por el ARN sin ruta arn:aws:iam::${aws_account_id}:role/AWSServiceRoleForAmazonEKSNodegroup, únicamente GetRole. Se conserva el ARN canónico con ruta para cuando exista. El diagnóstico OIDC38027564437 se detuvo antes de plan/apply y confirmó AccessDenied en GetRole. La segunda corrección restaura el estado38027207876 y actualiza únicamente ambas políticas EKS.
