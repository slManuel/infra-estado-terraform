# Infraestructura de estado Terraform

Infraestructura base para los estados Terraform de la prueba DevOps.

Declara un bucket S3 con bloqueo de acceso público, versionado, cifrado AES256 y política que exige HTTPS. También declara el proveedor OIDC de GitHub y tres roles con políticas de acceso al estado: red, Jenkins/Vault y microservicio.

## Bootstrap

El proveedor OIDC y el rol `prueba-devops-github-actions-estado` ya se crearon manualmente. El workflow usa ese rol mediante OIDC, sin claves AWS guardadas en GitHub, e importa el proveedor existente. El rol bootstrap sigue administrado manualmente.

Esta publicación no significa que el bucket esté desplegado: eso requiere revisar y aprobar el plan.

## Plan y aprobación manual

- Un push a `main` genera el plan completo; nunca ejecuta apply automáticamente.
- Los pull requests solo comprueban formato y validez, sin autenticarse en AWS.
- Revisa `plan.txt` dentro del artefacto `terraform-plan-RUN_ID-1`.
- Para aprobar, `slManuel` pulsa **Run workflow** en `main`, elige `operation=apply` y completa `plan_run_id`, `plan_commit` y `plan_sha256` usando el resumen del plan revisado.

El apply verifica identidad, commit vigente, antigüedad máxima de 24 horas e integridad del paquete. Aplica exactamente el plan binario guardado, con su estado de entrada y lock de proveedores, sin generar otro plan. Rechaza eliminaciones, reemplazos y reintentos ambiguos.

## Estado provisional

El backend es **local**; la migración del estado al bucket S3 queda para después.

El plan se conserva como artefacto durante **1 día** y el respaldo de estado durante **14 días**. Son archivos sensibles, descargables por quienes tengan acceso suficiente al repositorio privado; no deben compartirse. Los logs de plan/apply no se imprimen.

Después de un apply, genera el siguiente plan con **Run workflow**, `operation=plan`, `restore_run_id` del último apply ejecutado y `restore_run_attempt=1`. El workflow exige ese respaldo y detiene un push sin estado si los recursos ya existen.

Conserva el último estado válido antes de que expire. Una pérdida del runner o fallo al subir el respaldo requiere recuperación; este mecanismo no sustituye un backend remoto. Si cambian recursos directamente en AWS, revisa y reconcilia el estado antes de aprobar otro plan.

## Archivos

- `s3.tf`: bucket y protecciones.
- `oidc.tf` e `imports.tf`: proveedor GitHub existente y su adopción.
- `iam.tf`: tres roles y sus políticas de estado.
- `.github/workflows/terraform.yml`: plan y apply con aprobación manual.
- `versions.tf`, `providers.tf`, `variables.tf` y `outputs.tf`: versiones, cuenta/región, entradas y salida.

El workflow usa Terraform `1.15.9` y proveedor AWS `6.68.0`, en `us-east-1`. El estado, los planes, las variables reales y las credenciales están excluidos de Git.
