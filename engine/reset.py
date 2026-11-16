#!/usr/bin/env python3
"""Level lifecycle: cluster cleanup, sandbox refresh, and running level scripts.

Shared by the game engine and by scripts/test_levels.py so both exercise the
exact same code path.

The game cluster is dedicated to ArgoMissions, so a reset may remove every
Application, AppProject (except `default`), repository / cluster secret, every
Gitea repo in the `platform` org, and every namespace outside PROTECTED_NAMESPACES.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from rich.console import Console

console = Console()

REPO_ROOT = Path(__file__).resolve().parent.parent
BASELINE = REPO_ROOT / "engine" / "baseline"
DEFAULT_CONTEXT = "kind-argomissions"
ARGO_NS = "argocd"
GIT_USER, GIT_PASS, GIT_ORG = "player", "argomissions", "platform"
CLEANUP_LABEL = "argomissions.io/cleanup=true"
PROTECTED_NAMESPACES = {
    "default", "kube-system", "kube-public", "kube-node-lease", "local-path-storage", "argocd", "gitea",
}
CLUSTER_SCOPED_KINDS = (
    "customresourcedefinitions,clusterroles,clusterrolebindings,priorityclasses,storageclasses,"
    "ingressclasses,validatingwebhookconfigurations,mutatingwebhookconfigurations,persistentvolumes"
)
ARGO_DEPLOYMENTS = ("argocd-server", "argocd-repo-server", "argocd-applicationset-controller",
                    "argocd-notifications-controller")


def expected_context() -> str:
    return os.environ.get("ARGOMISSIONS_CONTEXT", DEFAULT_CONTEXT)


def git_port() -> str:
    return os.environ.get("AM_GIT_PORT", "3300")


def argocd_port() -> str:
    return os.environ.get("AM_ARGOCD_PORT", "9080")


def sandbox_root() -> Path:
    return Path(os.environ.get("ARGOMISSIONS_SANDBOX_ROOT", REPO_ROOT / "sandbox"))


def sandbox_dir() -> Path:
    return sandbox_root() / "current"


def game_env() -> dict[str, str]:
    """Environment that points kubectl and argocd at the game cluster only."""
    env = os.environ.copy()
    env.setdefault("KUBECONFIG", str(REPO_ROOT / ".am-shared" / "kubeconfig"))
    env.setdefault("ARGOCD_OPTS", f"--config {REPO_ROOT / '.am-shared' / 'argocd' / 'config'}")
    env.setdefault("AM_GIT_PORT", git_port())
    env.setdefault("AM_ARGOCD_PORT", argocd_port())
    return env


def _run(args: list[str], timeout: int = 120, **kwargs) -> subprocess.CompletedProcess[str]:
    kwargs.setdefault("env", game_env())
    try:
        return subprocess.run(args, capture_output=True, text=True, check=False, timeout=timeout, **kwargs)
    except subprocess.TimeoutExpired as exc:
        return subprocess.CompletedProcess(args, 124, exc.stdout or "", f"timed out after {timeout}s")
    except FileNotFoundError as exc:
        return subprocess.CompletedProcess(args, 127, "", str(exc))


def _kubectl_json(*args: str) -> dict:
    res = _run(["kubectl", *args, "-o", "json"], timeout=60)
    try:
        return json.loads(res.stdout or "{}")
    except json.JSONDecodeError:
        return {}


# ─────────────────────────────────────────────────────────────────────────────
# Context guard — never touch a cluster that is not the ArgoMissions one
# ─────────────────────────────────────────────────────────────────────────────

def current_context() -> str:
    return _run(["kubectl", "config", "current-context"], timeout=10).stdout.strip()


def context_is_safe() -> bool:
    return current_context() == expected_context()


def switch_context() -> bool:
    return _run(["kubectl", "config", "use-context", expected_context()], timeout=10).returncode == 0


def argocd_login() -> bool:
    """Make sure the argocd CLI (game config) has a valid session."""
    info = _run(["argocd", "account", "get-user-info", "-o", "json"], timeout=20)
    if info.returncode == 0 and '"loggedIn": true' in info.stdout:
        return True
    res = _run(["argocd", "login", f"localhost:{argocd_port()}", "--plaintext", "--username", "admin",
                "--password", "argomissions", "--name", "argomissions"], timeout=60)
    return res.returncode == 0


# ─────────────────────────────────────────────────────────────────────────────
# Environment for level scripts
# ─────────────────────────────────────────────────────────────────────────────

def level_env(level_path: Path) -> dict[str, str]:
    env = game_env()
    env.update(
        {
            "LEVEL_DIR": str(level_path),
            "SANDBOX": str(sandbox_dir()),
            "AM_LIB": str(REPO_ROOT / "engine" / "lib" / "common.sh"),
            "AM_ROOT": str(REPO_ROOT),
            "AM_PYTHON": sys.executable,
        }
    )
    return env


def run_level_script(level_path: Path, script: str, timeout: int = 600) -> subprocess.CompletedProcess[str] | None:
    """Run setup.sh / validate.sh / solve.sh / tests/*.sh for a level. Returns None if missing."""
    path = level_path / script
    if not path.exists():
        return None
    cwd = sandbox_dir()
    cwd.mkdir(parents=True, exist_ok=True)
    return _run(["bash", str(path)], timeout=timeout, cwd=cwd, env=level_env(level_path))


# ─────────────────────────────────────────────────────────────────────────────
# Cleanup
# ─────────────────────────────────────────────────────────────────────────────

def _strip_finalizers_and_delete(resource: str) -> list[str]:
    """Delete every object of an Argo CD kind in every namespace, without cascading."""
    items = _kubectl_json("get", resource, "-A").get("items", [])
    for item in items:
        meta = item["metadata"]
        if meta.get("finalizers"):
            _run(["kubectl", "patch", resource, meta["name"], "-n", meta["namespace"], "--type", "json",
                  "-p", '[{"op":"remove","path":"/metadata/finalizers"}]'], timeout=30)
    if items:
        _run(["kubectl", "delete", resource, "--all", "-A", "--wait=false"], timeout=60)
    return [i["metadata"]["name"] for i in items]


def _delete_all_applications(passes: int = 6) -> None:
    """Delete ApplicationSets and Applications until none come back.

    A self-healing root app (or an ApplicationSet) can re-create children, or re-add their finalizers, between
    our patch and delete. Repeat until the list stays empty for a few seconds."""
    for _ in range(passes):
        for resource in ("applicationsets.argoproj.io", "applications.argoproj.io"):
            _strip_finalizers_and_delete(resource)
        _wait_gone("applicationsets.argoproj.io", timeout=20)
        _wait_gone("applications.argoproj.io", timeout=20)
        time.sleep(3)
        if not (_kubectl_json("get", "applications.argoproj.io", "-A").get("items")
                or _kubectl_json("get", "applicationsets.argoproj.io", "-A").get("items")):
            return


def _wait_gone(resource: str, timeout: int = 60) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if not _kubectl_json("get", resource, "-A").get("items"):
            return
        time.sleep(1)


def _game_namespaces() -> list[str]:
    items = _kubectl_json("get", "namespaces").get("items", [])
    return [i["metadata"]["name"] for i in items if i["metadata"]["name"] not in PROTECTED_NAMESPACES]


def _strip_namespaced_finalizers(namespaces: list[str], kinds: str = "jobs.batch,pods") -> None:
    """Argo CD leaves argocd.argoproj.io/hook-finalizer on hook Jobs/Pods (e.g. a failed hook). Once its
    Application is gone nothing removes it, and the namespace would hang in Terminating."""
    for ns in namespaces:
        for item in _kubectl_json("get", kinds, "-n", ns).get("items", []):
            if item["metadata"].get("finalizers"):
                kind = item["kind"].lower() + ("" if item["kind"] == "Pod" else ".batch")
                _run(["kubectl", "patch", kind, item["metadata"]["name"], "-n", ns, "--type", "json",
                      "-p", '[{"op":"remove","path":"/metadata/finalizers"}]'], timeout=20)


def _wait_namespaces_gone(names: list[str], timeout: int = 180) -> None:
    deadline = time.time() + timeout
    remaining: set[str] = set(names)
    swept = False
    while time.time() < deadline:
        remaining = set(_game_namespaces()) & set(names)
        if not remaining:
            return
        if not swept and time.time() > deadline - timeout + 20:
            _strip_namespaced_finalizers(sorted(remaining))
            swept = True
        time.sleep(1)
    # A namespace stuck on a finalizer (e.g. a CR whose controller is gone): clear finalizers on its objects.
    for ns in remaining:
        _run(["kubectl", "patch", "namespace", ns, "--type", "json",
              "-p", '[{"op":"remove","path":"/spec/finalizers"}]'], timeout=20)
    raise RuntimeError(f"Timed out waiting for namespaces to delete: {', '.join(sorted(remaining))}")


def _cleanup_cluster_scoped() -> None:
    _run(["kubectl", "delete", CLUSTER_SCOPED_KINDS, "-l", CLEANUP_LABEL, "--wait=false"], timeout=60)
    # Game CRDs live in *.argomissions.io groups; a player may have applied one by hand (no label, no tracking).
    for crd in _kubectl_json("get", "customresourcedefinitions").get("items", []):
        if (crd.get("spec", {}).get("group") or "").endswith("argomissions.io"):
            _run(["kubectl", "delete", "customresourcedefinition", crd["metadata"]["name"], "--wait=false"], timeout=30)
    # Objects Argo CD created for earlier levels carry its tracking annotation.
    for kind in CLUSTER_SCOPED_KINDS.split(","):
        for item in _kubectl_json("get", kind).get("items", []):
            ann = item["metadata"].get("annotations") or {}
            if "argocd.argoproj.io/tracking-id" in ann:
                _run(["kubectl", "delete", kind, item["metadata"]["name"], "--wait=false"], timeout=30)


STOCK_REPO_SERVER = {"c": ["argocd-repo-server"], "i": ["copyutil"],
                     "v": ["ssh-known-hosts", "tls-certs", "gpg-keys", "gpg-keyring", "tmp", "helm-working-dir",
                           "argocd-repo-server-tls", "argocd-repo-server-mtls", "var-files", "plugins",
                           "argocd-cmd-params-cm"]}


def _restore_repo_server() -> bool:
    """Put argocd-repo-server back to the stock pod spec (levels may add a CMP sidecar). True if replaced."""
    spec = (_kubectl_json("get", "deploy", "argocd-repo-server", "-n", ARGO_NS).get("spec") or {})
    pod = (spec.get("template") or {}).get("spec") or {}
    shape = {"c": [c["name"] for c in pod.get("containers", [])], "i": [c["name"] for c in pod.get("initContainers", [])],
             "v": [v["name"] for v in pod.get("volumes", [])]}
    if not pod or shape == STOCK_REPO_SERVER:
        return False
    manifests = sorted((REPO_ROOT / ".am-shared" / "cache").glob("argocd-install-*.yaml"))
    if not manifests:
        return False
    import yaml  # local import: only needed on this rare path
    doc = next(d for d in yaml.safe_load_all(manifests[-1].read_text(encoding="utf-8"))
               if d and d.get("kind") == "Deployment" and d["metadata"]["name"] == "argocd-repo-server")
    doc["metadata"]["namespace"] = ARGO_NS
    doc["spec"]["template"]["spec"]["containers"][0].setdefault("env", []).append(
        {"name": "ARGOCD_RECONCILIATION_TIMEOUT",
         "valueFrom": {"configMapKeyRef": {"name": "argocd-cm", "key": "timeout.reconciliation", "optional": True}}})
    _run(["kubectl", "replace", "-f", "-"], input=yaml.safe_dump(doc), timeout=60)
    return True


def _wait_repo_server_mounts(before: dict[str, dict], timeout: int = 120) -> None:
    """repo-server reads known_hosts / TLS certs from ConfigMap volumes, which the kubelet refreshes about a
    minute after a change. If a level changed them, wait until repo-server sees the restored files, so the
    next level does not inherit a stale trusted host key."""
    import yaml
    checks = []
    if before.get("argocd-ssh-known-hosts-cm") != (yaml.safe_load((BASELINE / "argocd-ssh-known-hosts-cm.yaml")
                                                                  .read_text(encoding="utf-8")).get("data") or {}):
        expected = (yaml.safe_load((BASELINE / "argocd-ssh-known-hosts-cm.yaml").read_text(encoding="utf-8"))
                    .get("data") or {}).get("ssh_known_hosts", "")
        checks.append(("cat", "/app/config/ssh/ssh_known_hosts", expected.strip()))
    if before.get("argocd-tls-certs-cm"):
        checks.append(("ls", "/app/config/tls", ""))
    deadline = time.time() + timeout
    for cmd, path, expected in checks:
        while time.time() < deadline:
            res = _run(["kubectl", "-n", ARGO_NS, "exec", "deploy/argocd-repo-server", "-c", "argocd-repo-server",
                        "--", cmd, path], timeout=20)
            if res.returncode == 0 and res.stdout.strip() == expected:
                break
            time.sleep(3)


def _restore_argocd_baseline() -> None:
    """Undo level changes to Argo CD's own configuration."""
    cm_before = _kubectl_json("get", "configmap", "argocd-cm", "-n", ARGO_NS).get("data") or {}
    timeouts_changed = any(cm_before.get(k) != v for k, v in
                           (("timeout.reconciliation", "60s"), ("timeout.reconciliation.jitter", "0s"))) \
        or "timeout.hard.reconciliation" in cm_before
    cm = (BASELINE / "argocd-cm.yaml").read_text(encoding="utf-8").replace(
        "http://localhost:9080", f"http://localhost:{argocd_port()}")
    # `replace` drops keys a level added; `apply` would keep them.
    _run(["kubectl", "replace", "-f", "-"], input=cm, timeout=30)
    _run(["kubectl", "replace", "-f", str(BASELINE / "argocd-rbac-cm.yaml")], timeout=30)
    mounted_before = {cm: _kubectl_json("get", "configmap", cm, "-n", ARGO_NS).get("data") or {}
                      for cm in ("argocd-ssh-known-hosts-cm", "argocd-tls-certs-cm")}
    for extra in ("argocd-ssh-known-hosts-cm", "argocd-tls-certs-cm", "argocd-gpg-keys-cm", "argocd-notifications-cm"):
        _run(["kubectl", "replace", "-f", str(BASELINE / f"{extra}.yaml")], timeout=30)
    _wait_repo_server_mounts(mounted_before)
    # argocd-notifications-secret starts empty; levels may add webhook tokens to it.
    _run(["kubectl", "-n", ARGO_NS, "patch", "secret", "argocd-notifications-secret", "--type", "json",
          "-p", '[{"op":"remove","path":"/data"}]'], timeout=30)
    params_before = _kubectl_json("get", "configmap", "argocd-cmd-params-cm", "-n", ARGO_NS).get("data") or {}
    _run(["kubectl", "replace", "-f", str(BASELINE / "argocd-cmd-params-cm.yaml")], timeout=30)
    repo_server_replaced = _restore_repo_server()
    # Reconciliation timeouts and command parameters are read at start-up only.
    if params_before != {"server.insecure": "true"} or timeouts_changed or repo_server_replaced:
        _run(["kubectl", "-n", ARGO_NS, "rollout", "restart", *[f"deploy/{d}" for d in ARGO_DEPLOYMENTS],
              "statefulset/argocd-application-controller"], timeout=60)
        for d in ARGO_DEPLOYMENTS:
            _run(["kubectl", "-n", ARGO_NS, "rollout", "status", f"deploy/{d}", "--timeout=300s"], timeout=320)
        _run(["kubectl", "-n", ARGO_NS, "rollout", "status", "statefulset/argocd-application-controller",
              "--timeout=300s"], timeout=320)
    # Make sure every Argo CD component is back at its normal scale (levels may scale them down).
    for d in ARGO_DEPLOYMENTS:
        _run(["kubectl", "-n", ARGO_NS, "scale", f"deploy/{d}", "--replicas=1"], timeout=30)
    _run(["kubectl", "-n", ARGO_NS, "scale", "statefulset/argocd-application-controller", "--replicas=1"], timeout=30)
    # replace (not apply) so fields a level added to the default project are dropped too
    if _run(["kubectl", "replace", "-f", str(BASELINE / "default-project.yaml")], timeout=30).returncode != 0:
        _run(["kubectl", "create", "-f", str(BASELINE / "default-project.yaml")], timeout=30)
    # Keys levels add to argocd-secret: local-account passwords/tokens, webhook secrets.
    data = (_kubectl_json("get", "secret", "argocd-secret", "-n", ARGO_NS).get("data") or {})
    stale = [k for k in data if k.startswith(("accounts.", "webhook."))]
    if stale:
        ops = [{"op": "remove", "path": "/data/" + k.replace("~", "~0").replace("/", "~1")} for k in stale]
        _run(["kubectl", "-n", ARGO_NS, "patch", "secret", "argocd-secret", "--type", "json", "-p", json.dumps(ops)],
             timeout=30)
    # Level-created repository / repo-creds / cluster secrets, plus anything labelled for cleanup.
    _run(["kubectl", "-n", ARGO_NS, "delete", "secret", "-l", "argocd.argoproj.io/secret-type", "--wait=false"],
         timeout=30)
    _run(["kubectl", "-n", ARGO_NS, "delete", "secret,configmap", "-l", CLEANUP_LABEL, "--wait=false"], timeout=30)


def _cleanup_gitea() -> None:
    """Delete every repo in the platform org and every org / user a level created."""
    base = f"http://localhost:{git_port()}/api/v1"
    auth = ["-u", f"{GIT_USER}:{GIT_PASS}"]
    page = 1
    while True:
        res = _run(["curl", "-fsS", *auth, f"{base}/orgs/{GIT_ORG}/repos?limit=50&page={page}"], timeout=30)
        try:
            repos = json.loads(res.stdout or "[]")
        except json.JSONDecodeError:
            repos = []
        if not repos:
            break
        for repo in repos:
            _run(["curl", "-fsS", "-X", "DELETE", *auth, f"{base}/repos/{GIT_ORG}/{repo['name']}"], timeout=30)
    res = _run(["curl", "-fsS", *auth, f"{base}/admin/orgs?limit=50"], timeout=30)
    try:
        orgs = json.loads(res.stdout or "[]")
    except json.JSONDecodeError:
        orgs = []
    for org in orgs:
        name = org.get("username") or org.get("name")
        if name and name != GIT_ORG:
            _run(["curl", "-fsS", "-X", "DELETE", *auth, f"{base}/orgs/{name}?purge=true"], timeout=30)
    # Access tokens levels created for the player (SCM / PR generators, repo credentials).
    res = _run(["curl", "-fsS", *auth, f"{base}/users/{GIT_USER}/tokens?limit=50"], timeout=30)
    try:
        tokens = json.loads(res.stdout or "[]")
    except json.JSONDecodeError:
        tokens = []
    for token in tokens:
        _run(["curl", "-fsS", "-X", "DELETE", *auth, f"{base}/users/{GIT_USER}/tokens/{token['id']}"], timeout=30)
    res = _run(["curl", "-fsS", *auth, f"{base}/admin/users?limit=50"], timeout=30)
    try:
        users = json.loads(res.stdout or "[]")
    except json.JSONDecodeError:
        users = []
    for user in users:
        if user.get("login") not in (GIT_USER, None):
            _run(["curl", "-fsS", "-X", "DELETE", *auth, f"{base}/admin/users/{user['login']}?purge=true"], timeout=30)


def _flush_argocd_cache() -> None:
    """Repos are re-created with the same names for every level, but Argo CD caches branch → commit lookups
    and rendered manifests in Redis. Flush it so a level never sees the previous level's repo content."""
    _run(["kubectl", "-n", ARGO_NS, "exec", "deploy/argocd-redis", "-c", "redis", "--", "sh", "-c",
          'redis-cli -a "$REDIS_PASSWORD" --no-auth-warning flushall'], timeout=30)


def cleanup_cluster() -> None:
    """Remove everything previous levels may have left behind."""
    if not context_is_safe():
        raise RuntimeError(
            f"kubectl context is '{current_context()}', expected '{expected_context()}'. Refusing to reset."
        )
    _delete_all_applications()
    projects = [p["metadata"]["name"] for p in _kubectl_json("get", "appprojects", "-n", ARGO_NS).get("items", [])]
    for name in projects:
        if name != "default":
            _run(["kubectl", "-n", ARGO_NS, "patch", "appproject", name, "--type", "json",
                  "-p", '[{"op":"remove","path":"/metadata/finalizers"}]'], timeout=20)
            _run(["kubectl", "-n", ARGO_NS, "delete", "appproject", name, "--wait=false"], timeout=30)
    namespaces = _game_namespaces()
    for ns in namespaces:
        _run(["kubectl", "delete", "pods", "--all", "-n", ns, "--grace-period=0", "--force", "--wait=false"], timeout=30)
    _strip_namespaced_finalizers(namespaces)
    if namespaces:
        _run(["kubectl", "delete", "namespace", *namespaces, "--wait=false"], timeout=60)
    _cleanup_cluster_scoped()
    _restore_argocd_baseline()
    _cleanup_gitea()
    _flush_argocd_cache()
    if namespaces:
        _wait_namespaces_gone(namespaces)
    # A sync that was already running when the Applications went away may still create a namespace.
    late = _game_namespaces()
    if late:
        _strip_namespaced_finalizers(late)
        _run(["kubectl", "delete", "namespace", *late, "--wait=false"], timeout=60)
        _wait_namespaces_gone(late)


# ─────────────────────────────────────────────────────────────────────────────
# Sandbox + setup
# ─────────────────────────────────────────────────────────────────────────────

def refresh_sandbox(level_path: Path) -> Path:
    """Empty sandbox/current/ and copy the level's workspace/ files into it (setup.sh clones repos there)."""
    current = sandbox_dir()
    if current.exists():
        shutil.rmtree(current)
    current.mkdir(parents=True, exist_ok=True)
    workspace = level_path / "workspace"
    if workspace.exists():
        shutil.copytree(workspace, current, dirs_exist_ok=True)
    try:
        rel = level_path.relative_to(REPO_ROOT)
    except ValueError:
        rel = level_path
    (sandbox_root() / "LEVEL_INFO.txt").write_text(
        f"Active level: {rel}\n"
        f"Workspace:    {current}\n"
        f"Git (Gitea):  http://localhost:{git_port()}  (player / argomissions)\n"
        f"Argo CD UI:   http://localhost:{argocd_port()}  (admin / argomissions)\n"
        "Repos for the level are cloned into the workspace, ready to commit and push.\n",
        encoding="utf-8",
    )
    return current


def prepare_level(repo_root: Path, level_path: Path, quiet: bool = False) -> bool:
    """Reset the cluster and workspace, then build the level scenario. True when setup.sh succeeded."""
    del repo_root
    if not quiet:
        console.print("[grey70]Preparing mission: cleaning cluster state...[/grey70]")
    cleanup_cluster()
    argocd_login()
    workspace = refresh_sandbox(level_path)
    if not quiet:
        console.print("[grey70]Building the broken scenario...[/grey70]")
    result = run_level_script(level_path, "setup.sh")
    if result is not None and result.returncode != 0:
        console.print(f"[bold red]Level setup failed (exit {result.returncode}).[/bold red]")
        output = (result.stdout + "\n" + result.stderr).strip()
        if output:
            console.print(output[-3000:], markup=False, highlight=False)
        return False
    if not quiet:
        console.print(f"[grey70]Workspace ready at [bold]{workspace}[/bold][/grey70]")
    return True


def main() -> int:
    if len(sys.argv) != 2:
        console.print("Usage: python3 -m engine.reset <level-path>")
        return 1
    level_path = Path(sys.argv[1]).resolve()
    try:
        return 0 if prepare_level(REPO_ROOT, level_path) else 1
    except RuntimeError as exc:
        console.print(f"[red]Reset failed:[/red] {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
