# Roles IAM por proyecto

Un solo módulo administra los roles OIDC compartidos de red, herramientas y microservicio. `red.tf` y `jenkins_vault.tf` mantienen sus estados/políticas/trusts; `microservicio.tf` autoriza las ramas develop, qa y main, sus tres claves S3/locks en tres buckets, lectura de la red compartida y acceso desde Jenkins a las tres API privadas.

Entradas: aws_region, aws_account_id, state_bucket_arn (development), state_bucket_qa_arn, state_bucket_production_arn y github_oidc_provider_arn. Outputs: ARN de cada rol de GitHub Actions. Los nombres de roles y los moved históricos no cambian; el rol manual de bootstrap no se administra aquí.

Las políticas son explícitas, sin locals/for/for_each. Gestión IAM/PassRole usa el prefijo común prueba-devops-microservicio-*, compatible con los roles cluster/nodos/vpc-cni de los tres entornos. Las correcciones EKS/roles vinculados existentes se conservan. No se conceden permisos de destrucción ni de administración global a los pipelines. Comprobar plan, permisos efectivos y límites IAM antes de apply; el diseño nuevo no está aplicado.
