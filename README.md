# Infraestructura de estado Terraform

Administra **exactamente tres buckets**, un proveedor OIDC y los roles compartidos de GitHub Actions. Un solo root/estado Terraform es propietario de todo; este repositorio conserva `main`.

| Entorno | Bucket | Estados |
|---|---|---|
| development | `tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis` (existente) | `microservicio/development/terraform.tfstate`; excepción: red y herramientas en sus rutas actuales |
| qa | `tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis-qa` | `microservicio/qa/terraform.tfstate` |
| production | `tfstate-prueba-cuscatlan-oct2026-jose-manuel-solis-production` | `microservicio/production/terraform.tfstate` |

No se renombra el bucket actual ni se crea un cuarto. Red/tools siguen en `red-compartida/terraform.tfstate` y `jenkins-vault/terraform.tfstate` dentro de development. El estado del propio bootstrap continúa respaldado en Actions; migrarlo a S3 sigue pendiente.

## Carpetas

- `modules/bucket_estado`: módulo llamado tres veces; cifrado, versionado, bloqueo público y HTTPS.
- `modules/github_oidc`: único proveedor OIDC compartido.
- `modules/iam_roles`: permisos de estado y aprovisionamiento por proyecto.
- `scripts`, `tests`: compuerta del plan y pruebas sin AWS.
- `main.tf`, `imports.tf`, `moved.tf`: composición y conservación de recursos existentes.

El rol OIDC de microservicio acepta exactamente develop/qa/main y opera las tres claves/locks; los roles de red/tools conservan main y sus permisos. Se mantienen nombres IAM y el prefijo PassRole existente. La regla de API privada admite los tres nombres EKS desde Jenkins.

## Workflow

**1 workflow, 2 jobs, 22 pasos:** checks (5) → deploy (17). Push/PR a main solo valida. Deploy exige ejecución manual en main y `AWS_DEPLOY_ENABLED=true`; administra juntos los tres buckets, no solo producción.

Restaurar el respaldo del último apply mediante restore_run_id/restore_run_attempt. La compuerta solo admite 10 recursos nuevos de QA/production, dos políticas micro y el trust de su rol; todo lo demás debe ser no-op. Rechaza destrucción/reemplazo. El workflow aplica el mismo plan dentro de esa ejecución manual; **no es un flujo para obtener solamente un plan**. Estado: 14 días; plan/logs: un día.

| Job `checks`: paso | Función |
|---|---|
| 1. Checkout | Obtiene el código del repositorio. |
| 2. Setup Terraform | Instala Terraform 1.15.9. |
| 3. `terraform fmt -check -diff` | Comprueba recursivamente raíz, módulos y pruebas sin modificar archivos. |
| 4. `terraform init -backend=false` | Inicializa módulos y proveedores sin configurar el backend. |
| 5. `terraform validate` | Valida Terraform, prueba tres buckets con proveedor simulado y prueba la compuerta del plan. |

| Job `deploy`: paso | Función |
|---|---|
| 1. Checkout | Obtiene el código que se va a desplegar. |
| 2. Setup Terraform | Instala Terraform 1.15.9. |
| 3. Impedir rerun con artefactos ambiguos | Exige el primer intento del run. |
| 4. Exigir estado del último apply ejecutado | Comprueba que se seleccionó el run del último apply ejecutado, incluso si terminó con fallo. |
| 5. Restaurar respaldo elegido explícitamente | En ejecución manual con `restore_run_id`, descarga el estado del run e intento indicados. |
| 6. Autenticarse mediante OIDC | Asume el rol AWS de estado con credenciales temporales. |
| 7. Impedir plan nuevo sobre recursos sin estado | Valida el respaldo y bloquea el avance si cualquiera de los tres buckets o los tres roles existe sin registro en ese estado. |
| 8. Inicializar y validar | Ejecuta `terraform init` y `terraform validate`. |
| 9. Planificar configuración completa | Guarda `bootstrap.tfplan` y registra la salida en `plan.log`. |
| 10. Detener eliminaciones o reemplazos | Solo admite los 10 recursos S3 de QA/producción (create/no-op), las dos políticas de estado/provisioning micro y la confianza de su rol OIDC (update/no-op). Todo lo demás debe ser no-op; nunca delete/reemplazo. |
| 11. Preparar paquete de auditoría del plan | Reúne plan, lockfile y estado disponible, con manifiesto SHA-256, commit y run; publica sus referencias en el resumen. |
| 12. Guardar plan para auditoría | Sube el paquete como artefacto con retención de 1 día. |
| 13. Comprobar main antes de aplicar | Verifica que `main` todavía apunta al commit de la ejecución. |
| 14. Aplicar plan guardado | Aplica automáticamente el mismo `bootstrap.tfplan` y registra la salida en `apply.log`. |
| 15. Resumir resultado y diagnóstico | Incluso ante fallo, resume resultados y errores AWS de los logs disponibles. |
| 16. Conservar estado, también ante fallo parcial | Intenta respaldar los archivos de estado disponibles como artefacto durante 14 días. |
| 17. Conservar logs de Terraform, también ante fallo | Intenta guardar `plan.log` y `apply.log` como artefacto durante 1 día. |

## Estado

El bootstrap anterior tiene [evidencia real](imágenes/). Los dos buckets nuevos y los permisos ampliados están preparados localmente, sin plan/apply cloud. Falta comprobar nombres S3 disponibles, permisos del rol bootstrap y el plan con estado restaurado. El gate nuevo no se activó ni publicó. No se modifican OIDC ni recursos existentes mediante recreación.
