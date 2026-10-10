"""Allow only the two new buckets and the microservice policy/trust changes."""
import json
import subprocess
import sys

NEW_BUCKETS = {
    "module.bucket_estado_qa.aws_s3_bucket.bucket_estado_terraform",
    "module.bucket_estado_qa.aws_s3_bucket_public_access_block.bloqueo_publico_estado",
    "module.bucket_estado_qa.aws_s3_bucket_versioning.versionamiento_estado",
    "module.bucket_estado_qa.aws_s3_bucket_policy.exigir_https_estado",
    "module.bucket_estado_qa.aws_s3_bucket_server_side_encryption_configuration.cifrado_estado",
    "module.bucket_estado_production.aws_s3_bucket.bucket_estado_terraform",
    "module.bucket_estado_production.aws_s3_bucket_public_access_block.bloqueo_publico_estado",
    "module.bucket_estado_production.aws_s3_bucket_versioning.versionamiento_estado",
    "module.bucket_estado_production.aws_s3_bucket_policy.exigir_https_estado",
    "module.bucket_estado_production.aws_s3_bucket_server_side_encryption_configuration.cifrado_estado",
}
POLICIES = {
    "module.iam_roles.aws_iam_role.github_actions_microservicio",
    "module.iam_roles.aws_iam_role_policy.acceso_estado_microservicio",
    "module.iam_roles.aws_iam_role_policy.aprovisionar_microservicio",
}

def validate(plan):
    covered = set()
    for change in plan.get("resource_changes", []):
        if change.get("mode") == "data":
            continue
        address = change["address"]
        actions = change["change"]["actions"]
        if address in NEW_BUCKETS:
            allowed = actions in (["create"], ["no-op"])
            covered.add(address)
        elif address in POLICIES:
            allowed = actions in (["update"], ["no-op"])
            covered.add(address)
        else:
            allowed = actions == ["no-op"]
        if not allowed:
            raise ValueError("Cambio fuera del alcance: " + address + " " + str(actions))
    if covered != NEW_BUCKETS | POLICIES:
        raise ValueError("El plan no cubre los dos buckets nuevos y las políticas y confianza OIDC de microservicio")

if __name__ == "__main__":
    plan = json.loads(subprocess.check_output(["terraform", "show", "-json", sys.argv[1]], text=True))
    validate(plan)
    print("Alcance verificado: solo QA/production nuevos y políticas micro; desarrollo/OIDC/roles compartidos se conservan.")
