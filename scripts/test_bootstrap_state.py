import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from bootstrap_state import (LEGACY_SOURCE, backup, choose_state, latest_apply,
                             read_archive, select_artifact)

REPOSITORY = {"id": 42, "full_name": "owner/bootstrap"}


def run(identifier, conclusion="success", attempt=1):
    return {"id": identifier, "repository": REPOSITORY, "workflow_id": 7,
            "head_branch": "main", "event": "push", "run_attempt": attempt,
            "status": "completed", "conclusion": conclusion, "head_sha": "a" * 40}


def step(started, conclusion="success"):
    return {"name": "Aplicar plan guardado", "status": "completed",
            "conclusion": conclusion, "started_at": started}


def state(serial=27, lineage="existing-lineage"):
    return json.dumps({"version": 4, "lineage": lineage, "serial": serial,
                       "resources": [{"type": "aws_s3_bucket"}]}).encode()


def archive(files):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as z:
        for name, content in files.items():
            z.writestr(name, content)
    return output.getvalue()


def artifact(source, attempt, raw):
    return {"id": 123, "name": f'terraform-state-{source["id"]}-{attempt}', "expired": False,
            "digest": "sha256:" + hashlib.sha256(raw).hexdigest(),
            "workflow_run": {"id": source["id"], "head_sha": source["head_sha"],
                             "head_branch": "main", "repository_id": 42, "head_repository_id": 42}}


class RestoreTests(unittest.TestCase):
    def test_latest_failed_partial_apply_over_success_and_skipped(self):
        runs = [run(99), run(3), run(2, "failure", attempt=2), run(1)]
        jobs = {"3/attempts/1": step(None, "skipped"),
                "2/attempts/2": step("2026-10-10T03:00:00Z", "failure"),
                "2/attempts/1": step("2026-10-10T02:00:00Z", "failure"),
                "1/attempts/1": step("2026-10-10T01:00:00Z")}

        def get(path):
            if "/workflows/" in path:
                return {"workflow_runs": runs}
            for key, value in jobs.items():
                if "/runs/" + key + "/jobs?" in path:
                    return {"jobs": [{"steps": [value]}]}
            self.fail("Unexpected API query: " + path)

        source, attempt = latest_apply(run(99), get)
        self.assertEqual((source["id"], attempt), (2, 2))

    def test_no_history_blocks_empty_bootstrap(self):
        with self.assertRaisesRegex(ValueError, "estado vacío"):
            latest_apply(run(99), lambda _: {"workflow_runs": []})

    def test_missing_expired_duplicate_and_wrong_origin_block(self):
        source = run(2)
        valid = artifact(source, 1, b"archive")
        cases = [[], [dict(valid, expired=True)], [valid, valid],
                 [dict(valid, workflow_run={**valid["workflow_run"], "head_repository_id": 77})],
                 [dict(valid, digest=None)]]
        for entries in cases:
            with self.subTest(entries=len(entries)), self.assertRaises(ValueError):
                select_artifact(run(99), source, 1, lambda _: {"artifacts": entries})

    def test_confirmed_transition_backup_and_digest(self):
        source = run(LEGACY_SOURCE[0], "failure")
        raw = archive({"terraform.tfstate": state(), "terraform.tfstate.backup": state(26)})
        metadata = artifact(source, 1, raw)
        actual, _ = read_archive(raw, metadata, run(99), source, 1)
        self.assertEqual(actual["serial"], 27)
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            read_archive(raw + b"tampered", metadata, run(99), source, 1)
        with self.assertRaisesRegex(ValueError, "transición"):
            read_archive(raw, metadata, run(99), run(1), 1)

    def test_never_fallback_to_backup_or_empty_state(self):
        for files in ({"terraform.tfstate.backup": state()},
                      {"terraform.tfstate": b'{}'},
                      {"terraform.tfstate": state().replace(b'[{"type": "aws_s3_bucket"}]', b'[]')}):
            with self.subTest(files=list(files)), self.assertRaises(ValueError):
                choose_state(files)

    def test_partial_state_serial_lineage_and_conflict(self):
        selected, actual, _ = choose_state({"terraform.tfstate": state(26), "errored.tfstate": state(27)})
        self.assertEqual((selected, actual["serial"]), ("errored.tfstate", 27))
        for other in (state(27, "foreign-lineage"), state(26, "foreign-lineage")):
            with self.assertRaises(ValueError):
                choose_state({"terraform.tfstate": state(27), "errored.tfstate": other})
        conflicting = json.loads(state())
        conflicting["resources"].append({"type": "unexpected"})
        with self.assertRaisesRegex(ValueError, "mismo serial"):
            choose_state({"terraform.tfstate": state(), "errored.tfstate": json.dumps(conflicting).encode()})

    def test_new_backup_roundtrip_and_manifest_tampering(self):
        source = run(5, "failure")
        original = Path.cwd()
        env = {"GITHUB_REPOSITORY": REPOSITORY["full_name"], "GITHUB_RUN_ID": "5",
               "GITHUB_RUN_ATTEMPT": "1", "GITHUB_SHA": source["head_sha"], "APPLY_OUTCOME": "failure"}
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, env), patch("bootstrap_state.api", return_value=source):
            try:
                os.chdir(folder)
                Path("terraform.tfstate").write_bytes(state(26))
                Path("errored.tfstate").write_bytes(state(27))
                backup()
                files = {p.name: p.read_bytes() for p in Path(".state-backup").iterdir()}
                raw = archive(files)
                actual, _ = read_archive(raw, artifact(source, 1, raw), run(99), source, 1)
                self.assertEqual(actual["serial"], 27)
                manifest = json.loads(files["state-manifest.json"])
                manifest["commit"] = "b" * 40
                files["state-manifest.json"] = json.dumps(manifest).encode()
                raw = archive(files)
                with self.assertRaisesRegex(ValueError, "Manifiesto"):
                    read_archive(raw, artifact(source, 1, raw), run(99), source, 1)
            finally:
                os.chdir(original)

    def test_archive_paths_blocked(self):
        source = run(LEGACY_SOURCE[0])
        raw = archive({"../terraform.tfstate": state()})
        with self.assertRaisesRegex(ValueError, "Contenido inesperado"):
            read_archive(raw, artifact(source, 1, raw), run(99), source, 1)

    def test_workflow_push_only_apply_without_manual_gate(self):
        workflow = Path(__file__).resolve().parents[1] / ".github/workflows/terraform.yml"
        text = workflow.read_text()
        self.assertIn("github.ref == 'refs/heads/main' && github.event_name == 'push'", text)
        self.assertNotIn("workflow_dispatch:", text)
        self.assertNotIn("vars.AWS_DEPLOY_ENABLED", text)
        self.assertIn("cancel-in-progress: false", text)
        self.assertIn("terraform apply -no-color -input=false -lock-timeout=5m bootstrap.tfplan", text)


if __name__ == "__main__":
    unittest.main()
