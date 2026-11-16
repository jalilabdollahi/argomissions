# ArgoMissions Level Specification

Every level is hand-authored. There is no generator. A level is a directory
`modules/module-<M>-<name>/level-<N>-<slug>/` and is the single source of truth for that mission.
The curriculum (what each level teaches and breaks) lives in [CURRICULUM.md](CURRICULUM.md).
The reference level is `modules/module-1-basics/level-1-first-application/` — read it before writing one.

## 1. The world the player lives in

* A dedicated kind cluster with **Argo CD v3.6.1** (full install, namespace `argocd`, dex scaled to 0) and
  **Gitea 28.4** (namespace `gitea`). The player works from a second terminal after `source ./env.sh`.
* Argo CD UI/API: `http://localhost:9080`, user `admin` / `argomissions`. The `argocd` CLI is already
  logged in (plain-text gRPC, game config file — never `~/.config/argocd`).
* Gitea: `http://localhost:3300`, user `player` / `argomissions` (site admin). All level repos live in the
  org **`platform`**.
* **Two URLs for one repo** — this is how real clusters work and some levels use it:
  - the player clones `http://localhost:3300/platform/<repo>.git` (`am_repo_host_url`)
  - Argo CD reads `http://gitea.gitea.svc.cluster.local:3000/platform/<repo>.git` (`am_repo_url`).
  `localhost` inside the cluster is the repo-server pod itself, so an Application with the localhost URL fails.
* `argocd-cm` baseline: `timeout.reconciliation: 60s`, jitter 0 (repo-server is wired to the same value), so
  a push shows up within ~60 s; a refresh (`argocd app get X --refresh`, the Refresh button) is instant.
* Before every level the engine restores this world: deletes all ApplicationSets/Applications (finalizers
  stripped, no cascade), all AppProjects except `default`, all secrets labelled
  `argocd.argoproj.io/secret-type` in `argocd`, every namespace that is not
  `default|kube-*|local-path-storage|argocd|gitea`, cluster-scoped objects labelled
  `argomissions.io/cleanup=true` or carrying Argo's tracking annotation, every repo in the Gitea `platform`
  org plus orgs/users other than `platform`/`player`; then `kubectl replace`s `argocd-cm`, `argocd-rbac-cm`,
  `argocd-cmd-params-cm` (restarting Argo CD if cmd-params changed), `argocd-ssh-known-hosts-cm`, `argocd-tls-certs-cm`,
  `argocd-gpg-keys-cm`, `argocd-notifications-cm` (all from engine/baseline/), empties `argocd-notifications-secret`,
  restores the `default` AppProject, removes
  `accounts.*` and `webhook.*` keys from `argocd-secret`, and scales
  Argo CD components back to 1. Then it empties the workspace, copies `workspace/` (if any) into it and runs
  `setup.sh`.

## 2. Directory layout

```
level-N-slug/
  mission.yaml          briefing metadata (required)
  repo/ or repos/<name>/  Git content that setup.sh seeds into Gitea (one repo → repo/, several → repos/<name>/)
  assets/               other private files for setup/solve (Application manifests, later commits, ...)
  workspace/            optional extra files copied into the player's workspace before setup.sh
  setup.sh              builds the broken scenario (required)
  validate.sh           decides pass/fail (required)
  solve.sh              reference solution, executed only by the test harness (required)
  tests/
     fail-*.sh          a plausible WRONG / partial fix → validate.sh must still FAIL afterwards (≥ 1 required)
     alt-*.sh           an alternative CORRECT fix → validate.sh must PASS afterwards
  hint-1.txt hint-2.txt hint-3.txt
  solution-guide.md     step-by-step walkthrough (required)
  debrief.md            the lesson shown after passing (required)
```

## 3. mission.yaml

```yaml
name: "Works On My Laptop"               # short, evocative title
description: |                           # SITUATION: what the operator observes — symptoms and the exact
  The `orders` Application shows ...      # error text if there is one. 2-5 sentences. NEVER the fix.
objective: |                             # SUCCESS CRITERIA in observable terms: Application names, repo,
  Application `orders` is Synced and ...  # namespaces, what must answer. Don't describe how to fix it.
xp: 100
difficulty: beginner                     # beginner | intermediate | advanced | expert
expected_time: 10m
concepts: [Application, repoURL, repo-server]
```

## 4. Script contract

All scripts are run with `bash <script>`, **cwd = `$SANDBOX`** (the player's workspace), environment:

| Var | Meaning |
|-----|---------|
| `LEVEL_DIR` | absolute path of the level directory |
| `SANDBOX` | the player workspace (emptied before setup) |
| `AM_LIB` | helper library — every script must `source "$AM_LIB"` |
| `AM_PYTHON` | python3 with PyYAML |
| `KUBECONFIG`, `ARGOCD_OPTS` | point kubectl / argocd at this game cluster (do not override) |
| `AM_GIT_PORT`, `AM_ARGOCD_PORT` | host ports (differ per test slot — never hard-code 3300/9080) |

Start every script with:

```bash
#!/bin/bash
set -euo pipefail        # validate.sh: `set -uo pipefail` and fail through am_fail
source "$AM_LIB"
```

Read [engine/lib/common.sh](../engine/lib/common.sh). Main helpers:

* **Git:** `am_repo_seed NAME DIR [MSG]` (PRIVATE=1 for a private repo), `am_repo_commit NAME DIR MSG`
  (`DELETE="a b"`, `BRANCH=x`), `am_repo_branch`, `am_repo_delete_branch`, `am_repo_tag`, `am_repo_head NAME [BRANCH]`,
  `am_repo_checkout NAME DIR [BRANCH]`, `am_workspace_clone NAME [DIR]` (clone into the workspace, push-ready),
  `am_player_push DIR MSG` (commit+push from a workspace clone, for solve/tests), `am_repo_url`,
  `am_repo_host_url`, `am_gitea METHOD PATH [JSON]`.
* **Argo CD:** `am_app_apply FILE`, `am_app APP JSONPATH`, `am_app_sync/health/rev/op/json/conditions`,
  `am_app_refresh APP [normal|hard]`, `[PRUNE=1] am_app_sync_now APP [REV]` (a sync like the UI button), 
  `am_wait_app APP sync=Synced health=Healthy op=Failed rev=SHA oprev=SHA cond=TEXT opmsg=TEXT --timeout N`,
  `am_require_app_at_head APP REPO [BRANCH]`, `am_require_synced_by_argo APP REPO [BRANCH]` (the last sync
  operation deployed head — use it when a matching kubectl patch must not pass), `am_argocd ARGS`.
* **Kubernetes:** `am_jsonpath`, `am_wait_rollout`, `am_ready_replicas`, `am_endpoints_count`,
  `am_http URL NS` (curl from a throwaway pod), `am_yaml_get`, `am_yaml_docs_json`.
* **Output:** `am_info`, `am_ok`, `am_fail MSG [FILE]`, `am_pass`, `am_setup_assert "what" CMD...`, `am_wait SECS CMD...`,
  and an auto-cleaned temp dir `$AM_TMP`.

Never pin a kube context, never call `argocd` directly (use `am_argocd`), never hard-code host ports.
`am_wait` / `am_setup_assert` run a *command*: `am_wait 60 test "$(am_app_sync x)" = Synced` evaluates the
`$(...)` once, before waiting. Wrap dynamic checks in a function: `synced() { [ "$(am_app_sync x)" = Synced ]; }`
then `am_wait 60 synced`.

### setup.sh
* Seeds the repo(s) (`am_repo_seed shop "$LEVEL_DIR/repo"`), adds later commits if the story needs history,
  creates Applications/AppProjects/secrets (`am_app_apply "$LEVEL_DIR/assets/app.yaml"`), simulates the
  colleague's mistake, and clones the repos the player must edit into the workspace (`am_workspace_clone shop`).
* Application manifests reference repos by the in-cluster URL. Write it literally in YAML:
  `http://gitea.gitea.svc.cluster.local:3000/platform/<repo>.git` (it is the same in every slot).
* **Assert** the intended broken state was reached, waiting for Argo CD where needed
  (`am_wait_app shop op=Failed --timeout 120 || { echo "setup: sync did not fail"; exit 1; }`).
* Deterministic, re-runnable, < 3 minutes. Always `am_app_refresh` after creating apps whose repo was just seeded.

### validate.sh
* **Behaviour-based.** Check what must be true: Application sync/health/revision, live objects, what the
  service answers, what is in Git (`am_repo_checkout` then inspect). Never `diff` against a solution.
* **GitOps-honest.** Git is the source of truth: when the lesson is "fix it in Git", a live `kubectl` hotfix
  must fail (the app is OutOfSync, or the Git content is still wrong). Usually check
  `am_require_app_at_head` — synced to the *current head*, not an old revision.
* Prints a line per check (`am_ok`), fails with a message naming the *symptom*, not the answer. Exit 0 = pass.
* Fast (< 90 s), read-only. It must fail right after setup (the harness checks this).

### solve.sh
What a player would do: edit files in the workspace clone and `am_player_push`, run `am_argocd app ...`,
`kubectl` commands. Wait for the result (`am_argocd app sync X --timeout 120`, `am_wait_app`). It must make
validate.sh pass.

### tests/
At least one `tests/fail-*.sh` per level with the most tempting wrong fix (kubectl hotfix instead of a Git
change, changing Git but never syncing, a forced push that rewrites history, deleting and re-creating instead of
fixing ...). Add `tests/alt-*.sh` when several fixes are valid (CLI vs YAML vs UI-equivalent `kubectl patch`).
Same env and cwd as solve.sh; a test must leave the cluster settled (wait for the sync it started).

## 5. Cluster & environment rules

* Namespaces: realistic names (`payments`, `shop-staging`, ...), unique per level, never `default`,
  `argocd`, `gitea`, `kube-*`. Levels own every other namespace; the engine deletes them.
* Applications, AppProjects, ApplicationSets live in `argocd` (unless the lesson is apps-in-any-namespace).
* Cluster-scoped objects a level creates directly must carry label `argomissions.io/cleanup: "true"` and a name
  containing `argomissions` (CRD group `*.argomissions.io`). Objects Argo CD creates are cleaned automatically.
* Images (pre-pulled in the node, exact tags, `imagePullPolicy: IfNotPresent`):
  `hashicorp/http-echo:1.0` (answers a fixed text: `args: ["-text=orders v1.2", "-listen=:5678"]` — the
  default port 5678), `nginx:1.27-alpine`, `nginxinc/nginx-unprivileged:1.27-alpine` (uid 101, port 8080),
  `busybox:1.36`, `curlimages/curl:8.10.1`, `traefik/whoami:v1.10`. A deliberately broken tag is fine for
  ImagePullBackOff stories — use a tag that can never exist (`1.O`, `1.27-alpien`), because the node CAN reach
  Docker Hub: a real-but-old tag would pull fine. No other images; never depend on internet access.
* Small pods: requests ≤ 50m CPU / 64Mi, `terminationGracePeriodSeconds: 2`, replicas 1–2.
* Player tools: `argocd`, `kubectl` (incl. `kubectl kustomize`), `git`, `jq`, `curl`, `helm` may be used for
  local rendering only. Gitea UI and Argo CD UI are always available — a level may say "use the UI" but must be
  solvable with the CLI too (solve.sh proves that).
* **Verify every premise on this exact Argo CD (v3.6.1) before building a level.** Argo CD 3.x changed several
  defaults vs 2.x (annotation-based resource tracking, fine-grained RBAC for update/delete, logs RBAC enforced,
  `ApplyOutOfSyncOnly` ...). If a curriculum premise is false, adapt the scenario minimally so the same lesson
  holds and mention the difference in the debrief (`## Argo CD 2.x vs 3.x` section). Known so far:
  - an `operation` patched onto an Application does not inherit `spec.syncPolicy.syncOptions` — the CLI and UI
    copy them in; `am_app_sync_now` does too;
  - repo-server caches branch → commit lookups for `ARGOCD_RECONCILIATION_TIMEOUT` (default 3m, here 60s).

## 6. Writing quality

* **Every level is unique.** Different app/repo/namespace names, a different domain (shop, payments,
  search, telemetry, ledger, billing, ...), a different repo shape. Keep repos small and realistic (only the
  manifests the story needs). The broken thing must be exactly what the curriculum entry says, nothing else.
* **Realistic.** Errors are the real Argo CD / Kubernetes errors. The player discovers the problem with real
  commands (`argocd app get X`, `argocd app diff`, `argocd app history`, `argocd app manifests`,
  `kubectl describe`, `kubectl get events`, `git log`) or the UI.
* The app usually answers a version string (`http-echo -text=...`) so validators can prove what is live.
* hint-1: where to look (a diagnostic command). hint-2: what is wrong. hint-3: almost the fix. 2–6 lines each.
* solution-guide.md: numbered walkthrough with exact commands, what the output shows, the change, how to verify.
* debrief.md (≥ 800 chars) with these sections: `## What broke` · `## Why Argo CD behaves this way` ·
  `## The fix` · `## In real life` (where this bites teams) · `## Commands worth remembering` ·
  `## Common mistakes` (2–3 bullets) · and, when relevant, `## Argo CD 2.x vs 3.x`.

## 7. Testing

```bash
source scripts/agent_env.sh <slot>      # own cluster am-w<slot>; first time ≈ 3 min
venv/bin/python scripts/test_levels.py -v modules/module-1-basics/level-1-first-application
venv/bin/python scripts/test_levels.py --module module-1-basics
venv/bin/python scripts/test_levels.py --static-only --all
```

Shell state does not persist between tool calls, so prefix every command with the `source` line.
The harness: static checks → reset + setup → validate must FAIL → solve → validate must PASS → every
`tests/*.sh` from a fresh setup (fail-* must leave validate failing, alt-* must make it pass).
A level is done only when the harness prints `[PASS]` for it.
