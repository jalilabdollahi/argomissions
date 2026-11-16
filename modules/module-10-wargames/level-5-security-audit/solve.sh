#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# Finding 1: default read-only, kim admin, the pipeline gets its own narrow role
kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.default":"","policy.csv":"g, sam, role:readonly\np, role:custody-deployer, applications, get, custody/*, allow\np, role:custody-deployer, applications, sync, custody/*, allow\ng, kim, role:admin\ng, deploy-bot, role:custody-deployer\n"}}' >/dev/null

# Finding 3: one credential template for the machine user (and the machine user must be able to read both repos)
am_gitea PUT /repos/platform/custody-batch/collaborators/argo-reader '{"permission":"read"}' >/dev/null
kubectl -n argocd delete secret repo-custody-api repo-custody-batch >/dev/null
am_argocd repocreds add "$AM_GIT_INCLUSTER/platform" --username argo-reader --password reader-pass-8Rt3 >/dev/null

# Finding 4: only the two RBAC kinds
kubectl -n argocd patch appproject custody --type merge -p '{"spec":{"clusterResourceWhitelist":[{"group":"rbac.authorization.k8s.io","kind":"ClusterRole"},{"group":"rbac.authorization.k8s.io","kind":"ClusterRoleBinding"}]}}' >/dev/null

# Finding 2: the password leaves Git; a new one is generated and lives only in the cluster
cd "$SANDBOX/custody-api"
git pull -q
git rm -q deploy/db-secret.yaml
am_player_push . "remove the committed database password; the Secret is created out of band"
head="$(am_repo_head custody-api)"
am_argocd app get custody-api --hard-refresh >/dev/null
am_wait_app custody-api rev="$head" sync=Synced --timeout 150
kubectl -n custody create secret generic custody-db --from-literal=password="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n custody delete pod -l app=custody-api --wait=false >/dev/null
am_argocd app get custody-batch --hard-refresh >/dev/null
am_wait_app custody-api sync=Synced health=Healthy --timeout 150
am_wait_app custody-batch sync=Synced health=Healthy --timeout 150
sleep 6
