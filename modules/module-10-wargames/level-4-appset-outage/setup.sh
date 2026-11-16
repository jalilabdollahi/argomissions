#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed orbit-services "$LEVEL_DIR/repos/orbit-services" "orbit-services: ingest, rollup, alerts v1"
am_repo_seed orbit-control "$LEVEL_DIR/repos/orbit-control" "orbit-fleet ApplicationSet"
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/control-app.yaml"
am_app_refresh orbit-control

# The repo-server caches branch -> commit lookups (60s), also for repos that were just re-seeded, so the set may
# briefly see an earlier run's content: nudge the controller until it sees the fresh repos.
settle() {  # settle CMD...
  local i
  for i in $(seq 1 12); do
    am_wait 15 "$@" && return 0
    am_app_refresh orbit-control
    kubectl -n argocd annotate applicationset orbit-fleet argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null 2>&1 || true
  done
  return 1
}
three() { local a; for a in orbit-ingest orbit-rollup orbit-alerts; do kubectl -n argocd get application "$a" >/dev/null || return 1; done; }
settle three || { echo "setup: the three Applications were not generated"; exit 1; }
for s in ingest rollup alerts; do
  am_wait_app "orbit-$s" sync=Synced health=Healthy --timeout 150 || { echo "setup: orbit-$s did not become healthy"; exit 1; }
done
am_wait_app orbit-control sync=Synced health=Healthy --timeout 90 || { echo "setup: orbit-control did not settle"; exit 1; }

# 02:55 - the "tidy-up" is merged. The generator now matches no folder and the set deletes what it generated.
am_repo_commit orbit-control "$LEVEL_DIR/assets/bad-commit" "Simplify generator globs"
am_app_refresh orbit-control
none() { [ -z "$(kubectl -n argocd get applications -o name | grep -E 'orbit-(ingest|rollup|alerts)')" ]; }
settle_none() {
  local i
  for i in $(seq 1 12); do
    am_wait 15 none && return 0
    am_app_refresh orbit-control
    kubectl -n argocd annotate applicationset orbit-fleet argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null 2>&1 || true
  done
  return 1
}
settle_none || { echo "setup: the generated Applications were not deleted"; exit 1; }
gone() { local s; for s in ingest rollup alerts; do ! kubectl -n "orbit-$s" get deploy "orbit-$s" >/dev/null 2>&1 || return 1; done; }
am_wait 120 gone || { echo "setup: the workloads were not deleted"; exit 1; }

# 03:00 - what on-call tried: pause the automation of orbit-control "so it stops fighting us", and a "temporary"
# tightening of the project.
kubectl -n argocd patch application orbit-control --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}' >/dev/null
kubectl -n argocd patch appproject orbit --type merge --patch-file "$LEVEL_DIR/assets/project-tightened.yaml" >/dev/null
am_workspace_clone orbit-control
am_workspace_clone orbit-services
