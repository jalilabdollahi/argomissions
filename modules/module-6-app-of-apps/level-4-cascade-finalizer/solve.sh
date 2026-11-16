#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl get deploy,svc -n tariff-old
kubectl -n tariff-old get deploy tariff-legacy -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}{"\n"}'
cd "$SANDBOX/tariff-gitops"
git log --oneline --stat -3

# Step 1: every child Application gets the finalizer, and the retired one comes back (with it) so Argo CD owns it again.
git show HEAD~1:apps/legacy.yaml >apps/legacy.yaml
for f in apps/api.yaml apps/legacy.yaml; do
  sed -i.bak 's/^  namespace: argocd/  namespace: argocd\n  finalizers:\n  - resources-finalizer.argocd.argoproj.io/' "$f" && rm "$f.bak"
done
am_player_push . "Applications: resources-finalizer; restore tariff-legacy to retire it properly"
head="$(am_repo_head tariff-gitops)"
am_app_refresh tariff-root
am_wait_app tariff-root rev="$head" sync=Synced --timeout 120
am_wait_app tariff-legacy sync=Synced health=Healthy --timeout 150
am_wait 60 bash -c 'kubectl -n argocd get application tariff-legacy -o jsonpath="{.metadata.finalizers}" | grep -q resources-finalizer'

# Step 2: retire it again: the cascade deletes the workload this time.
git rm -q apps/legacy.yaml
am_player_push . "retire tariff-legacy (cascade)"
head="$(am_repo_head tariff-gitops)"
am_app_refresh tariff-root
am_wait_app tariff-root rev="$head" sync=Synced --timeout 120
am_wait 120 bash -c '! kubectl -n argocd get application tariff-legacy'
am_wait 120 bash -c '! kubectl -n tariff-old get deploy tariff-legacy'
am_app_refresh tariff-api
am_wait_app tariff-api rev="$head" sync=Synced health=Healthy --timeout 120
