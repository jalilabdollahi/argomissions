#!/bin/bash
set -euo pipefail
source "$AM_LIB"

KNOWN=/app/config/ssh/ssh_known_hosts
# The known-hosts ConfigMap is restored by the engine, but the repo-server sees ConfigMap changes with a
# delay (volume refresh): drop any gitea entry and wait until the repo-server's file really lacks it.
cur="$(kubectl -n argocd get cm argocd-ssh-known-hosts-cm -o jsonpath='{.data.ssh_known_hosts}')"
printf '%s\n' "$cur" | grep -v 'gitea' >"$AM_TMP/known_hosts" || true
kubectl -n argocd create cm argocd-ssh-known-hosts-cm --from-file=ssh_known_hosts="$AM_TMP/known_hosts" --dry-run=client -o yaml \
  | kubectl -n argocd patch cm argocd-ssh-known-hosts-cm --type merge --patch-file /dev/stdin >/dev/null
repo_server_clean() {
  kubectl -n argocd exec deploy/argocd-repo-server -c argocd-repo-server -- sh -c "test -f $KNOWN && ! grep -q gitea $KNOWN"
}
am_wait 150 repo_server_clean || { echo "setup: repo-server still trusts gitea"; exit 1; }

PRIVATE=1 am_repo_seed fleet-agent "$LEVEL_DIR/repo" "fleet-agent v5.0"
ssh-keygen -q -t ed25519 -N "" -C "argocd-deploy-key" -f "$AM_TMP/deploy"
am_gitea POST /repos/platform/fleet-agent/keys \
  "$(jq -n --rawfile k "$AM_TMP/deploy.pub" '{title:"argocd (read-only)",key:$k,read_only:true}')" >/dev/null

kubectl create namespace fleet >/dev/null
kubectl -n argocd create secret generic repo-fleet-agent \
  --from-literal=type=git \
  --from-literal=url=ssh://git@gitea.gitea.svc.cluster.local:22/platform/fleet-agent.git \
  --from-file=sshPrivateKey="$AM_TMP/deploy" >/dev/null
kubectl -n argocd label secret repo-fleet-agent argocd.argoproj.io/secret-type=repository >/dev/null

am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh fleet-agent
unknown() { am_app_conditions fleet-agent | grep -q 'knownhosts: key is unknown'; }
am_wait 90 unknown || { echo "setup: Argo CD did not report 'knownhosts: key is unknown'"; exit 1; }
