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

**1 workflow, 2 jobs, 22 pasos:** checks (5) → deploy (17). Cada push o merge a `main` ejecuta automáticamente validación, restauración, plan, compuerta de alcance, apply del mismo archivo y respaldo. Los PR hacia main solo ejecutan checks, sin credenciales AWS. No requiere aprobación, ejecución manual ni variable AWS_DEPLOY_ENABLED. Solo este bootstrap compartido usa ese automatismo.

La restauración busca mediante la API de GitHub el último intento de apply de este mismo workflow/repositorio/main, incluso si terminó con fallo parcial. Exige su artefacto exacto no expirado, valida origen/commit/intento y SHA-256 del ZIP. Los respaldos nuevos incluyen manifiesto con SHA-256 del estado, linaje y serial. Solo el respaldo confirmado `terraform-state-38069049415-1` admite el formato histórico sin manifiesto, como transición inicial. Nunca usa un estado vacío, un respaldo anterior ni el archivo `.backup` para sustituir un estado actual ausente. Un primer despliegue sin historial exige un procedimiento explícito separado.

La compuerta solo admite los 10 recursos S3 de QA/production (create/no-op), las dos políticas micro y la confianza de su rol (update/no-op); todo lo demás debe ser no-op. Rechaza eliminaciones y reemplazos. El apply conserva el plan guardado y comprueba que main sigue en el mismo commit. Las ejecuciones se serializan sin cancelar un apply anterior; reruns ambiguos se rechazan. Estado: 14 días; plan/logs: un día. Si el último respaldo falta o expira, el despliegue se detiene y requiere recuperación explícita; estos artefactos aún no sustituyen un backend persistente.

| Job `checks`: paso | Función |
|---|---|
| 1. Checkout | Obtiene el código. |
| 2. Setup Terraform | Instala Terraform 1.15.9. |
| 3. Formato | Comprueba raíz, módulos y pruebas sin modificar archivos. |
| 4. Init sin backend | Inicializa módulos y proveedores. |
| 5. Validación y pruebas | Valida Terraform, simula tres buckets y prueba alcance/restauración segura. |

| Job `deploy`: paso | Función |
|---|---|
| 1. Checkout | Obtiene el commit de main que se desplegará. |
| 2. Setup Terraform | Instala Terraform 1.15.9. |
| 3. Impedir rerun ambiguo | Exige el primer intento del run. |
| 4. Restaurar automáticamente | Localiza el último apply, descarga su artefacto exacto y verifica integridad antes de escribir el estado. |
| 5. OIDC | Asume el rol AWS de estado con credenciales temporales. |
| 6. Verificar estado frente a AWS | Bloquea recursos existentes sin registro en el estado restaurado. |
| 7. Inicializar y validar | Conecta la configuración al estado y valida Terraform. |
| 8. Planificar | Guarda bootstrap.tfplan y plan.log. |
| 9. Compuerta de alcance | Rechaza eliminaciones, reemplazos o modificaciones no autorizadas. |
| 10. Preparar auditoría | Reúne plan, lockfile y estado con hashes, commit y run. |
| 11. Guardar auditoría | Conserva el paquete privado durante un día. |
| 12. Comprobar main | Verifica que main todavía apunta al commit ejecutado. |
| 13. Aplicar plan guardado | Aplica el mismo bootstrap.tfplan y registra apply.log. |
| 14. Resumir resultado | Resume resultados y errores, incluso ante fallo. |
| 15. Preparar respaldo | Selecciona el estado actual de mayor serial, comprueba linaje y genera su manifiesto; también ante fallo parcial. |
| 16. Conservar estado | Sube el estado y manifiesto como artefacto privado durante 14 días, incluso ante fallo. |
| 17. Conservar logs | Guarda plan.log/apply.log durante un día, incluso ante fallo. |

## Historial verificado y recuperación

La [ejecución 38069049415](https://github.com/slManuel/infra-estado-terraform/actions/runs/38069049415) restauró el estado existente y verificó un plan de **10 creaciones, 3 cambios, 0 eliminaciones**. Se actualizaron la confianza y la política de aprovisionamiento del rol microservicio; los dos buckets nuevos fallaron con AccessDenied para s3:CreateBucket. El estado parcial quedó conservado como `terraform-state-38069049415-1`, serial 27, y es la base de la restauración automática. El 10 de octubre se guardó y verificó en IAM la ampliación del rol bootstrap exclusivamente a los ARN QA/production en sus tres bloques S3; acciones y condiciones originales se conservaron. El bucket original/OIDC/roles compartidos no se recrearon. [Evidencia previa](imágenes/).

La ejecución automática 38069815451 restauró ese estado, pero CreateBucket volvió a ser denegado antes del ajuste IAM; no completó creaciones ni modificaciones. Su respaldo posterior se omitió por la exclusión de carpetas ocultas de upload-artifact. La subida ahora incluye include-hidden-files=true. La recuperación única autorizada está documentada en `.github/state-recovery.json`: fija run/intento/commit e IDs/hashes de los paquetes de plan y logs del mismo intento, hash del estado y linaje, serial 27. No contiene el estado. Solo permite recuperar ese snapshot si no hubo operaciones completadas; el siguiente plan debe contrastar AWS y admitir exactamente las 10 creaciones y la política de estado micro pendiente, sin cambios en los demás recursos. Un run distinto, hash diferente, operaciones completadas o drift bloquean el avance. Después del próximo apply se usará su respaldo nuevo con manifiesto. Consultar [Actions](https://github.com/slManuel/infra-estado-terraform/actions/workflows/terraform.yml) para el resultado más reciente.
