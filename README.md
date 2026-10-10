# Infraestructura de estado Terraform

Infraestructura base para los estados Terraform de la prueba DevOps.

Declara un bucket S3 con bloqueo de acceso público, versionado, cifrado AES256 y política que exige HTTPS. También declara el proveedor OIDC de GitHub y tres roles con políticas de acceso al estado: red, Jenkins/Vault y microservicio. El rol de red incluye una política EC2 para aprovisionar la red compartida. Jenkins/Vault y microservicio tienen políticas de capacidad EKS en la región configurada, con roles de ejecución separados por prefijo.

## Bootstrap

El proveedor OIDC y el rol `prueba-devops-github-actions-estado` ya se crearon manualmente. El workflow usa ese rol mediante OIDC, sin claves AWS guardadas en GitHub, e importa el proveedor existente. El rol bootstrap sigue administrado manualmente.

El resultado real de cada despliegue se comprueba en GitHub Actions: un plan exitoso por sí solo no demuestra que el apply haya terminado.

## Plan y apply automático

- Un push a `main` ejecuta formato, inicialización y validación; genera un plan nuevo y aplica automáticamente ese mismo archivo en el mismo job.
- Los pull requests solo comprueban formato y validez, sin autenticarse en AWS.
- El workflow bloquea eliminaciones/reemplazos, reintentos ambiguos, commits que ya no sean la punta de `main` y recursos existentes sin estado recuperado.
- `plan.txt`, el plan binario y su manifiesto de hashes quedan en `terraform-plan-RUN_ID-1` para auditoría.

El apply utiliza `bootstrap.tfplan`, generado en esa ejecución, con el mismo estado y lock de proveedores. El workflow serializa las ejecuciones y conserva un respaldo incluso tras un fallo parcial normal.

## Estado provisional

El backend es **local**; la migración del estado al bucket S3 queda para después.

El plan se conserva como artefacto durante **1 día** y el respaldo de estado durante **14 días**. Son archivos sensibles, descargables por quienes tengan acceso suficiente al repositorio privado; no deben compartirse. Los logs de plan/apply no se imprimen.

Después de un apply, inicia el siguiente despliegue con **Run workflow** en `main`, `restore_run_id` del último apply ejecutado y `restore_run_attempt=1`. Esta ejecución restaura el estado y luego planifica y aplica automáticamente. El workflow exige ese respaldo y detiene un push sin estado si los recursos ya existen.

Conserva el último estado válido antes de que expire. Una pérdida del runner o fallo al subir el respaldo requiere recuperación; este mecanismo no sustituye un backend remoto. Si cambian recursos directamente en AWS, revisa y reconcilia el estado antes de iniciar otro despliegue.

## Permisos de red

La política se escribe como una lista literal de `Statement`, con permisos explícitos y sin `locals`, bucles ni composición dinámica. `jsonencode` convierte ese objeto HCL en el JSON que IAM recibe.

`aprovisionar_red` permite crear VPC, subredes, tablas de rutas, Internet Gateway, EIP, NAT Gateway y endpoint de S3. Limita las escrituras por cuenta, región y etiquetas `Project=prueba-devops` y `Component=red-compartida`: exige etiquetas de solicitud para recursos nuevos y etiquetas existentes para sus dependencias. El etiquetado inicial usa `ec2:CreateAction`; las actualizaciones de etiquetas no pueden alterar `Project` ni `Component`.

Las consultas EC2 enumeradas usan `Resource="*"` cuando AWS no admite ARN específicos; pueden leer recursos de la cuenta ajenos al proyecto en la región autorizada. `DescribeVpcAttribute` sí queda limitado a VPC etiquetadas. Las etiquetas no demuestran pertenencia al estado Terraform. La política no concede eliminación de infraestructura, EKS ni administración IAM; la retirada requiere revisar y autorizar permisos adicionales.

Con los valores actuales de cuenta/región, las dos políticas inline declaradas para el rol de red suman **7.668 caracteres compactos**: 674 de S3 y 6.994 de EC2, por debajo del límite agregado de 10.240 por rol. El cálculo no incluye políticas adicionales que pudieran agregarse fuera de este código. Los permisos declarados entran en vigor al aplicar Terraform.

Referencias: [autorización EC2](https://docs.aws.amazon.com/service-authorization/latest/reference/list_ec2.html), [etiquetado durante creación](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/supported-iam-actions-tagging.html) y [cuotas IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html).

## Estructura

main.tf conecta tres módulos locales. La raíz conserva providers.tf, versions.tf, variables.tf, outputs.tf, imports.tf, moved.tf y el workflow. No hay carpetas environments ni se cambia el backend local provisional.

- modules/bucket_estado: main.tf contiene el bucket y sus cuatro protecciones/configuraciones; variables.tf recibe su nombre; outputs.tf devuelve nombre y ARN.
- modules/github_oidc: main.tf contiene el proveedor OIDC; variables.tf recibe URL y audiencias; outputs.tf devuelve su ARN.
- modules/iam_roles: red.tf, jenkins_vault.tf y microservicio.tf contienen roles y políticas explícitas; variables.tf recibe cuenta/región y ARN de bucket/OIDC; outputs.tf devuelve los tres ARN de roles.
- Cada módulo declara requisitos en versions.tf y documenta su interfaz en README.md. La configuración AWS se pasa desde raíz, conservando etiquetas y cuenta autorizada.

La salida pública state_bucket_name conserva su valor mediante module.bucket_estado.bucket_name. Los roles reciben module.bucket_estado.bucket_arn y module.github_oidc.provider_arn; no duplican S3/OIDC. El rol manual de bootstrap sigue fuera de Terraform. Versiones sin cambios: Terraform >=1.15.0,<2.0.0, workflow 1.15.9 y AWS =6.68.0.

## Direcciones de estado e import

moved.tf contiene trece correspondencias directas desde las direcciones históricas de raíz a sus módulos finales: cinco S3, una OIDC y siete IAM. Doce corresponden a recursos existentes y una a aprovisionar_red, incorporada en el despliegue de permisos. Conservar estos bloques para actualizar estados anteriores; no se requieren movimientos manuales de estado.

imports.tf conserva el identificador del proveedor OIDC existente y apunta a module.github_oidc.aws_iam_openid_connect_provider.github_actions. No declara otro recurso OIDC. El próximo plan con estado restaurado debe resolver la correspondencia; nunca usar un fresh apply para recursos ya existentes.

Antes de ejecutar el siguiente despliegue, restaurar el respaldo del último apply. La validación offline y la equivalencia de configuración no prueban ausencia de recreaciones. Con el estado conocido y sin drift se esperan tres políticas nuevas, además de doce traslados de direcciones existentes. El workflow comprueba para esta actualización que solo se creen aprovisionar_red, aprovisionar_jenkins_vault y aprovisionar_microservicio y que los demás recursos tengan no-op. Cualquier otro cambio bloquea el apply. Esta comprobación deberá revisarse explícitamente para futuras ampliaciones.

Referencias: [refactorización con moved](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) y [providers en módulos](https://developer.hashicorp.com/terraform/language/modules/develop/providers).


## Capacidad EKS de los roles de despliegue

aprovisionar_jenkins_vault y aprovisionar_microservicio permiten crear, consultar y actualizar EKS, grupos de nodos, addons, accesos y asociaciones Pod Identity en aws_region. Permiten plantillas de lanzamiento y RunInstances en esa región; esto incluye capacidad de lanzar EC2 directamente. El etiquetado EC2 se limita a instancias, volúmenes y plantillas de la cuenta/región. No conceden eliminación de infraestructura ni publicación de imágenes ECR.

IAM se limita a roles con prefijos prueba-devops-jenkins-vault-* y prueba-devops-microservicio-*, respectivamente, cinco políticas administradas enumeradas y PassRole a eks.amazonaws.com/pods.eks.amazonaws.com. CreateRole y UpdateAssumeRolePolicy permiten definir confianza dentro de esos prefijos; no son una garantía absoluta contra delegación privilegiada. Se permite crear los dos service-linked roles de EKS y leer el usuario administrador manuel-dev. No se conceden PutRolePolicy sobre roles de ejecución, creación de políticas ni AdministratorAccess.

No se limita EKS al nombre de un clúster. La separación S3 conserva estado/lock propios y lectura del estado de red, y no restringe la administración de otros EKS en la región. Totales inline declarados: Jenkins/Vault 4.461 caracteres (883 S3 + 3.578 EKS), microservicio 4.464 (886 + 3.578), frente al límite agregado de 10.240; no incluyen políticas externas al código.

[Autorización EKS](https://docs.aws.amazon.com/service-authorization/latest/reference/list_eks.html) · [Autorización IAM](https://docs.aws.amazon.com/service-authorization/latest/reference/list_iam.html) · [Plantillas EKS](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html).


## Evidencia de despliegue

El run [38025501360](https://github.com/slManuel/infra-estado-terraform/actions/runs/38025501360) terminó success el 9 de octubre de 2026: doce movimientos, tres políticas añadidas, cero cambios y cero eliminaciones. Se restauró el estado del run38015534898. El nuevo respaldo vigente es terraform-state-38025501360-1, intento1; usarlo en la siguiente restauración mientras no exista otro apply posterior. El backend continúa local. La compuerta de alcance de esta actualización deberá revisarse para una operación futura.


Corrección de dependencias EKS: AmazonEBSCSIDriverPolicyV2 usa ARN arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2, sin service-role/. Ambas políticas de capacidad añaden iam:GetRole exclusivamente para AWSServiceRoleForAmazonEKS/AWSServiceRoleForAmazonEKSNodegroup. La compuerta de esta corrección exige solo dos updates de esas políticas, cero creaciones/eliminaciones; todos los demás recursos no-op. Se restaura el último respaldo38025501360. Fuente ARN: https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEBSCSIDriverPolicyV2.html .


La consulta IAM de un rol vinculado aún inexistente se autoriza también por el ARN sin ruta arn:aws:iam::${aws_account_id}:role/AWSServiceRoleForAmazonEKSNodegroup, únicamente GetRole. Se conserva el ARN canónico con ruta para cuando exista. El diagnóstico OIDC38027564437 se detuvo antes de plan/apply y confirmó AccessDenied en GetRole. La segunda corrección restaura el estado38027207876 y actualiza únicamente ambas políticas EKS.
