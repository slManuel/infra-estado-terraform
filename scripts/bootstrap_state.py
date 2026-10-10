"""Restore the latest attempted apply; never fall back to an older/empty state."""
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

APPLY_STEPS = {"Aplicar plan aprobado", "Aplicar plan guardado"}
LEGACY_SOURCE = (38069049415, 1)
STATE_FILES = {"terraform.tfstate", "errored.tfstate", "terraform.tfstate.backup"}


def api(path, binary=False):
    value = subprocess.check_output(["gh", "api", path])
    return value if binary else json.loads(value)


def pages(path, key, get):
    page = 1
    while True:
        result = get(path + ("&" if "?" in path else "?") + f"per_page=100&page={page}")[key]
        yield from result
        if len(result) < 100:
            return
        page += 1


def latest_apply(current, get):
    repo = current["repository"]
    base = "repos/" + repo["full_name"]
    candidates = []
    for run in pages(base + f'/actions/workflows/{current["workflow_id"]}/runs', "workflow_runs", get):
        if run["id"] == current["id"]:
            continue
        if (run["repository"]["id"] != repo["id"] or run["workflow_id"] != current["workflow_id"]
                or run["head_branch"] != "main" or run["event"] not in ("push", "workflow_dispatch")):
            continue
        for attempt in range(1, run["run_attempt"] + 1):
            jobs = pages(base + f'/actions/runs/{run["id"]}/attempts/{attempt}/jobs', "jobs", get)
            for job in jobs:
                for step in job.get("steps", []):
                    if (step["name"] not in APPLY_STEPS or step.get("conclusion") == "skipped"
                            or step["status"] not in ("in_progress", "completed")):
                        continue
                    if run["status"] != "completed":
                        raise ValueError("Otro apply todavía no terminó; no se puede restaurar su estado.")
                    started = step.get("started_at", "")
                    if not started or started.startswith("0001-"):
                        raise ValueError("Apply sin fecha verificable.")
                    candidates.append((started, run["id"], attempt, run))
    if not candidates:
        raise ValueError("No hay apply previo verificable; se prohíbe iniciar con estado vacío.")
    candidates.sort(key=lambda value: value[:3])
    newest = candidates[-1]
    if sum(item[0] == newest[0] for item in candidates) != 1:
        raise ValueError("Último apply ambiguo.")
    return newest[3], newest[2]


def select_artifact(current, run, attempt, get):
    base = "repos/" + current["repository"]["full_name"]
    name = f'terraform-state-{run["id"]}-{attempt}'
    matches = [a for a in pages(base + f'/actions/runs/{run["id"]}/artifacts', "artifacts", get)
               if a["name"] == name]
    if len(matches) != 1 or matches[0]["expired"]:
        raise ValueError("El respaldo del último apply falta, expiró o es ambiguo; no se usa uno anterior.")
    artifact = matches[0]
    origin = artifact["workflow_run"]
    if (origin["id"] != run["id"] or origin["head_sha"] != run["head_sha"]
            or origin["head_branch"] != "main"
            or origin["repository_id"] != current["repository"]["id"]
            or origin["head_repository_id"] != current["repository"]["id"]):
        raise ValueError("El artefacto no pertenece al repositorio/commit/ejecución esperados.")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", artifact.get("digest") or ""):
        raise ValueError("Artefacto sin SHA-256 verificable.")
    return artifact


def parse_state(raw):
    state = json.loads(raw)
    if (state.get("version") != 4 or not isinstance(state.get("lineage"), str)
            or not state["lineage"] or type(state.get("serial")) is not int or state["serial"] < 0
            or not isinstance(state.get("resources"), list) or not state["resources"]):
        raise ValueError("Estado inválido o vacío.")
    return state


def choose_state(files):
    # The .backup file may predate a partial apply: it is never a recovery fallback.
    candidates = [(name, parse_state(raw), raw) for name, raw in files.items()
                  if name in ("terraform.tfstate", "errored.tfstate")]
    if not candidates:
        raise ValueError("Respaldo sin estado actual; no se utiliza el archivo .backup.")
    if len({state["lineage"] for _, state, _ in candidates}) != 1:
        raise ValueError("Estados con linajes distintos.")
    candidates.sort(key=lambda item: item[1]["serial"])
    chosen = candidates[-1]
    for _, state, _ in candidates[:-1]:
        if state["serial"] == chosen[1]["serial"] and state != chosen[1]:
            raise ValueError("Estados incompatibles con el mismo serial.")
    return chosen


def read_archive(raw, artifact, current, run, attempt):
    if "sha256:" + hashlib.sha256(raw).hexdigest() != artifact["digest"]:
        raise ValueError("SHA-256 del ZIP no coincide con GitHub.")
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        names = archive.namelist()
        if (len(names) != len(set(names)) or not set(names) <= STATE_FILES | {"state-manifest.json"}
                or sum(info.file_size for info in archive.infolist()) > 20 * 1024 * 1024):
            raise ValueError("Contenido inesperado, duplicado o excesivo en el respaldo.")
        files = {name: archive.read(name) for name in names}
    name, state, content = choose_state(files)
    if "state-manifest.json" not in files:
        if (run["id"], attempt) != LEGACY_SOURCE:
            raise ValueError("Solo el respaldo de transición confirmado puede carecer de manifiesto.")
    else:
        manifest = json.loads(files["state-manifest.json"])
        expected = {"repository": current["repository"]["full_name"],
                    "workflow_id": current["workflow_id"], "run_id": run["id"],
                    "run_attempt": attempt, "commit": run["head_sha"],
                    "lineage": state["lineage"], "serial": state["serial"],
                    "state_sha256": hashlib.sha256(content).hexdigest()}
        if any(manifest.get(key) != value for key, value in expected.items()) or name != "terraform.tfstate":
            raise ValueError("Manifiesto del estado inconsistente con su origen o contenido.")
    return state, content


def private_write(path, content):
    path.write_bytes(content)
    path.chmod(0o600)


def restore():
    repo, run_id = os.environ["GITHUB_REPOSITORY"], os.environ["GITHUB_RUN_ID"]
    current = api(f"repos/{repo}/actions/runs/{run_id}")
    if (current["repository"]["full_name"] != repo or current["head_sha"] != os.environ["GITHUB_SHA"]
            or current["head_branch"] != "main" or current["event"] != "push"):
        raise ValueError("La restauración automática exige push de main del repositorio actual.")
    run, attempt = latest_apply(current, api)
    artifact = select_artifact(current, run, attempt, api)
    raw = api(f'repos/{repo}/actions/artifacts/{artifact["id"]}/zip', binary=True)
    state, content = read_archive(raw, artifact, current, run, attempt)
    private_write(Path("terraform.tfstate"), content)
    with open(os.environ["GITHUB_ENV"], "a") as output:
        output.write(f'RESTORE_RUN_ID={run["id"]}\nRESTORE_RUN_ATTEMPT={attempt}\n')
    message = f'Estado restaurado automáticamente: run {run["id"]}, intento {attempt}, serial {state["serial"]}.'
    print(message)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as output:
        output.write(message + "\n")


def backup():
    files = {name: Path(name).read_bytes() for name in ("terraform.tfstate", "errored.tfstate")
             if Path(name).exists()}
    if not files:
        if os.environ.get("APPLY_OUTCOME") in ("success", "failure", "cancelled"):
            raise ValueError("Apply intentado sin estado para respaldar.")
        print("Sin estado restaurado ni apply; no se genera un respaldo vacío.")
        return
    _, state, content = choose_state(files)
    current = api(f'repos/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{os.environ["GITHUB_RUN_ID"]}')
    manifest = {"repository": os.environ["GITHUB_REPOSITORY"], "workflow_id": current["workflow_id"],
                "run_id": int(os.environ["GITHUB_RUN_ID"]), "run_attempt": int(os.environ["GITHUB_RUN_ATTEMPT"]),
                "commit": os.environ["GITHUB_SHA"], "lineage": state["lineage"], "serial": state["serial"],
                "state_sha256": hashlib.sha256(content).hexdigest()}
    folder = Path(".state-backup")
    folder.mkdir(mode=0o700)
    private_write(folder / "terraform.tfstate", content)
    private_write(folder / "state-manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())
    print(f'Estado actual preparado para respaldo: serial {state["serial"]}.')


if __name__ == "__main__":
    try:
        {"restore": restore, "backup": backup}[sys.argv[1]]()
    except (ValueError, KeyError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error)) from error
