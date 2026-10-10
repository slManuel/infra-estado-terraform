# Bucket de estado

Módulo reutilizado explícitamente por `bucket_estado` (development existente), `bucket_estado_qa` y `bucket_estado_production`. Cada llamada crea cinco recursos: bucket sin force_destroy, bloqueo público, versionado, cifrado AES256 y política HTTPS. El bucket existente recibe etiquetas vacías para conservar sus default tags; los nuevos sobrescriben Environment con qa/production.

Entradas: bucket_name y bucket_tags. Outputs: bucket_name y bucket_arn. No configura backend ni migra estados. Versiones: Terraform >=1.15.0,<2.0.0, AWS=6.68.0. Los moved históricos del bucket development permanecen en raíz; los dos módulos nuevos no reclaman recursos existentes.
