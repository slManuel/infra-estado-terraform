# Proveedor OIDC de GitHub

main.tf contiene el mismo aws_iam_openid_connect_provider.github_actions. Entradas obligatorias: provider_url (string) y client_id_list (list(string)). Raíz conserva https://token.actions.githubusercontent.com y la audiencia sts.amazonaws.com. La salida provider_arn conecta las confianzas de iam_roles.

No se cambia ninguna confianza IAM. El rol manual de bootstrap queda fuera del módulo. El import declarativo permanece en raíz con su identificador original y destino module.github_oidc.aws_iam_openid_connect_provider.github_actions; moved.tf raíz conserva la correspondencia desde la dirección OIDC desplegada. No se crea una segunda declaración de proveedor OIDC.

versions.tf conserva Terraform >=1.15.0,<2.0.0 y hashicorp/aws =6.68.0; aws se recibe desde raíz. Antes de un despliegue se debe restaurar el último estado y revisar el plan real. La organización local no demuestra por sí sola ausencia de recreación ni implica cambios AWS.

[Refactorización moved](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) · [Providers en módulos](https://developer.hashicorp.com/terraform/language/modules/develop/providers).
