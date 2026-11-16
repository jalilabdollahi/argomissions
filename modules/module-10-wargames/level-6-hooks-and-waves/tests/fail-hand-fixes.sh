#!/bin/bash
# Wrong: the cluster is fixed by hand (Role, CRD, old Job) and only the test is fixed in Git. The sync is green,
# but Git still orders nothing and rota-crds is still manual and OutOfSync.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/shiftboard"
git pull -q
sed -i.bak 's#http://shiftboard-api/#http://shiftboard/#' deploy/smoke-test.yaml && rm -f deploy/smoke-test.yaml.bak
kubectl -n shiftboard apply -f deploy/rbac.yaml >/dev/null
kubectl apply -f crds/shift-policy.yaml >/dev/null
kubectl -n shiftboard delete job rota-migrate --ignore-not-found >/dev/null
am_player_push . "smoke test: call the real Service"
head="$(am_repo_head shiftboard)"
am_app_refresh shiftboard
am_wait_app shiftboard rev="$head" --timeout 120
am_argocd app sync shiftboard --timeout 240
am_wait_app shiftboard sync=Synced health=Healthy op=Succeeded --timeout 150
