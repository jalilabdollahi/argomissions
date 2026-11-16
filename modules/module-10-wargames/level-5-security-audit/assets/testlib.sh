# shellcheck shell=bash
# Shared by the tests of this level: each function applies one finding's correct fix.
fix_access() {
  kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.default":"","policy.csv":"g, sam, role:readonly\np, role:custody-deployer, applications, get, custody/*, allow\np, role:custody-deployer, applications, sync, custody/*, allow\ng, kim, role:admin\ng, deploy-bot, role:custody-deployer\n"}}' >/dev/null
}
fix_creds() {
  am_gitea PUT /repos/platform/custody-batch/collaborators/argo-reader '{"permission":"read"}' >/dev/null
  kubectl -n argocd delete secret repo-custody-api repo-custody-batch >/dev/null
  am_argocd repocreds add "$AM_GIT_INCLUSTER/platform" --username argo-reader --password reader-pass-8Rt3 >/dev/null
}
fix_project() {
  kubectl -n argocd patch appproject custody --type merge -p '{"spec":{"clusterResourceWhitelist":[{"group":"rbac.authorization.k8s.io","kind":"ClusterRole"},{"group":"rbac.authorization.k8s.io","kind":"ClusterRoleBinding"}]}}' >/dev/null
}
# push the custody-api change in the workspace and wait for the sync
push_api() {
  am_player_push "$SANDBOX/custody-api" "$1"
  local head; head="$(am_repo_head custody-api)"
  am_argocd app get custody-api --hard-refresh >/dev/null
  am_argocd app get custody-batch --hard-refresh >/dev/null
  am_wait_app custody-api rev="$head" sync=Synced --timeout 150
}
settle() {
  am_wait_app custody-api sync=Synced health=Healthy --timeout 150
  am_wait_app custody-batch sync=Synced health=Healthy --timeout 150
  sleep 6
}
