# Infraestructura de estado Terraform

Infraestructura base para los estados Terraform de la prueba DevOps.

Declara un bucket S3 con bloqueo de acceso público, versionado, cifrado AES256 y política que exige HTTPS. También declara el proveedor OIDC de GitHub y tres roles con políticas de acceso al estado: red, Jenkins/Vault y microservicio.

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

## Archivos

- `s3.tf`: bucket y protecciones.
- `oidc.tf` e `imports.tf`: proveedor GitHub existente y su adopción.
- `iam.tf`: tres roles y sus políticas de estado.
- `.github/workflows/terraform.yml`: plan y apply automático del mismo archivo.
- `versions.tf`, `providers.tf`, `variables.tf` y `outputs.tf`: versiones, cuenta/región, entradas y salida.

El workflow usa Terraform `1.15.9` y proveedor AWS `6.68.0`, en `us-east-1`. El estado, los planes, las variables reales y las credenciales están excluidos de Git.
