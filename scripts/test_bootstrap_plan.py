import unittest
from check_bootstrap_plan import NEW_BUCKETS, POLICIES, validate

def fixture():
    changes = [{"address":a,"change":{"actions":["create"]}} for a in sorted(NEW_BUCKETS)]
    changes += [{"address":a,"change":{"actions":["update"]}} for a in sorted(POLICIES)]
    changes += [{"address":"module.bucket_estado.aws_s3_bucket.bucket_estado_terraform","change":{"actions":["no-op"]}}]
    return {"resource_changes":changes}

class BootstrapTests(unittest.TestCase):
    def test_expected_and_idempotent(self):
        validate(fixture())
        plan=fixture()
        for change in plan["resource_changes"]:change["change"]["actions"]=["no-op"]
        validate(plan)

    def test_reject_existing_bucket_change_delete_unexpected_and_missing(self):
        plan=fixture();plan["resource_changes"][-1]["change"]["actions"]=["update"]
        with self.assertRaises(ValueError):validate(plan)
        for actions in (["delete"],["delete","create"]):
            plan=fixture();plan["resource_changes"][0]["change"]["actions"]=actions
            with self.assertRaises(ValueError):validate(plan)
        plan=fixture();plan["resource_changes"].append({"address":"module.extra.aws_s3_bucket.extra","change":{"actions":["create"]}})
        with self.assertRaises(ValueError):validate(plan)
        plan=fixture();plan["resource_changes"].pop(0)
        with self.assertRaises(ValueError):validate(plan)

if __name__=="__main__":unittest.main()
