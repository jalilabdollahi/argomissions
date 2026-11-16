# ArgoMissions 🐙⚔️

![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)
![argocd](https://img.shields.io/badge/Argo%20CD-v3.6-ef7b4d)
![shell](https://img.shields.io/badge/shell-bash-brightgreen)

> **Learn Argo CD by breaking GitOps, then fixing it.**

ArgoMissions is a fully local, game-based Argo CD training platform with a rich terminal interface.
Every mission drops a broken GitOps setup in front of you — an Application that will not sync, a hook that
never runs, a project that denies everything, an ApplicationSet that ate the fleet. You fix it the way you
would at work: with `git`, the `argocd` CLI, the Argo CD UI and `kubectl`, against a real Argo CD and a real
Git server running in a local kind cluster.

**10 modules, from your first Application to production war games.** No cloud. No costs.

---

## ✨ Features

- 🐙 **Real Argo CD 3.6** (full install with UI) and a real **Gitea** Git server in the cluster
- 🌿 **Real Git workflow** — each level clones its repos into your workspace, ready to commit and push
- 🧪 **Behaviour-based validation** — any correct fix passes; `kubectl` hotfixes that break GitOps don't
- 💡 **Progressive hints**, a full walkthrough, and a **debrief** after each mission
- 👁️ **Watch mode** — re-validates every 5 seconds until you pass
- 🏅 **Module certificates** — earned only when every level of a module is solved
- 🔒 **Isolated** — the game has its own kubeconfig and argocd config; your `~/.kube/config` and
  `~/.config/argocd` are never touched

---

## 🚀 Quick Start

```bash
cd argomissions
./install.sh          # tools check, venv, kind cluster + Gitea + Argo CD (≈ 3 minutes the first time)
./play.sh             # terminal 1: the game
```

In a **second terminal**:

```bash
source ./env.sh       # kubectl + argocd now point at the game cluster only, cd into the workspace
argocd app list
```

| What | Where | Login |
|------|-------|-------|
| Argo CD UI / API | http://localhost:9080 | `admin` / `argomissions` |
| Gitea (Git server) | http://localhost:3300 | `player` / `argomissions` |
| Level workspace | `sandbox/current/` | repos are cloned here |

Argo CD reads the same repos through the in-cluster address
`http://gitea.gitea.svc.cluster.local:3000/platform/<repo>.git` — `localhost` inside the cluster is not your laptop.

## 📋 Prerequisites

| Tool | Install |
|------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | running, ≥ 4 GB memory for Docker |
| [kind](https://kind.sigs.k8s.io/) | `brew install kind` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | `brew install kubectl` |
| [argocd CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) | `brew install argocd` |
| git, jq, curl, Python 3.9+ | `brew install git jq python` |

## 🎮 How to Play

1. `./play.sh` — read the briefing (situation + objective)
2. Second terminal: `source ./env.sh`, investigate with `argocd app get`, `argocd app diff`, the UI, `kubectl`
3. Fix it — usually in Git (`cd <repo> && git commit -am ... && git push`), sometimes in the Application,
   the AppProject or Argo CD's own config
4. `check` in the game

## 🎯 Commands

| Command | Shortcut | Description |
|---------|----------|-------------|
| `check` | `1` | Validate your solution |
| `check-dry` | `d` | Run the validator without awarding XP |
| `watch` | `w` | Auto-validate every 5 seconds until pass |
| `hint` | `2` | Reveal the next of 3 progressive hints |
| `guide` | `3` | Full walkthrough |
| `debrief` | `4` | Re-read the lesson for the current level |
| `argocd <args>` | `5 <args>` | Run the argocd CLI through the safety guard |
| `kubectl <args>` | `5k <args>` | Run kubectl through the safety guard |
| `edit <kind> <name>` | `e` | Edit a live object in `$EDITOR` (default namespace `argocd`) |
| `reset` | `6` | Rebuild the current level from scratch |
| `status` | `7` | Module progress and XP |
| `skip` | `8` | Skip the level (no XP, no certificate) |
| `goto <M>.<L>` | | Jump to any level, e.g. `goto 2.3` |
| `quit` | `9` | Save and exit |

---

## 🗺️ Learning Path

| # | Module | Difficulty | Key Topics |
|---|--------|------------|------------|
| 1 | 🟢 Argo CD Basics | Beginner | Applications, repo URLs, paths, revisions, destinations, sync vs health, drift, prune, rollback |
| 2 | 🟢 Sync Policies & Drift | Beginner → Intermediate | automated, selfHeal, prune, ignoreDifferences, Replace, ServerSideApply, retry |
| 3 | 🟡 Helm, Kustomize & Sources | Intermediate | value files, parameters, release names, overlays, images, directory options, multi-source |
| 4 | 🟡 Sync Waves & Hooks | Intermediate → Advanced | PreSync/PostSync/SyncFail, waves, delete policies, CRD ordering, PruneLast |
| 5 | 🟡 Projects & RBAC | Intermediate → Advanced | AppProjects, local accounts, project roles & tokens, policies, sync windows |
| 6 | 🔴 App of Apps | Advanced | root apps, finalizers, app health in waves, self-management, bootstrap |
| 7 | 🔴 ApplicationSets | Advanced | list / git / cluster / matrix / merge / SCM / PR generators, goTemplate, safety |
| 8 | 🔴 Repositories, Clusters & Secrets | Advanced | private repos, repo-creds, SSH, cluster secrets, webhooks, signed commits |
| 9 | ⚫ Customization & Operations | Expert | Lua health checks, actions, exclusions, CMP plugins, notifications |
| 10 | ⚫ Production War Games | Expert | multi-fault incidents across the platform |

---

## 📁 Project Structure

```text
argomissions/
├── install.sh / play.sh / env.sh
├── infra/                 kind config, Gitea manifest
├── engine/
│   ├── engine.py          game loop and commands
│   ├── reset.py           cluster cleanup between levels, running level scripts
│   ├── safety.py          kubectl / argocd guards
│   ├── baseline/          Argo CD config restored before every level
│   └── lib/common.sh      bash helpers for level scripts (Git, Argo CD, Kubernetes)
├── scripts/
│   ├── cluster.sh         kind + Gitea + Argo CD bootstrap
│   ├── test_levels.py     end-to-end level tester
│   └── agent_env.sh       isolated cluster per level author (parallel authoring)
├── docs/LEVEL_SPEC.md, docs/CURRICULUM.md
└── modules/module-N-*/level-N-*/   mission.yaml, repo/, setup.sh, validate.sh, solve.sh, tests/, hints, debrief
```

## 🛠️ Authoring & testing levels

Read [docs/LEVEL_SPEC.md](docs/LEVEL_SPEC.md). Every level ships a reference `solve.sh` and tests for tempting
wrong fixes; the harness proves the validator fails on the broken state, passes after the fix, and rejects the
wrong ones:

```bash
venv/bin/python scripts/test_levels.py modules/module-1-basics/level-1-first-application
source scripts/agent_env.sh 1 && venv/bin/python scripts/test_levels.py --module module-1-basics
```

## 🧹 Uninstall

```bash
bash scripts/cluster.sh delete
```

## 📄 License

MIT License.
