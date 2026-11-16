#!/bin/bash
# ArgoMissions cluster bootstrap. Everything uses the game's own kubeconfig
# (.am-shared/kubeconfig); your ~/.kube/config is never read or changed.
#
#   scripts/cluster.sh create     kind cluster + Gitea + Argo CD + images + CLI login (idempotent)
#   scripts/cluster.sh argocd     (re)install / reconfigure Argo CD only
#   scripts/cluster.sh gitea      (re)install Gitea only
#   scripts/cluster.sh login      log the argocd CLI in (game config, not ~/.config/argocd)
#   scripts/cluster.sh status     show what is running
#   scripts/cluster.sh delete     delete the cluster
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="${1:-create}"
CLUSTER="${ARGOMISSIONS_CLUSTER:-argomissions}"
SHARED="$ROOT/.am-shared"
# Slots (scripts/agent_env.sh) override these to run several isolated clusters side by side.
export KUBECONFIG="${KUBECONFIG_GAME:-$SHARED/kubeconfig}"
ARGOCD_PORT="${AM_ARGOCD_PORT:-9080}"
GIT_PORT="${AM_GIT_PORT:-3300}"
SSH_PORT="${AM_SSH_PORT:-2223}"
ARGOCD_VERSION="v3.6.1"
ARGOCD_MANIFEST="$SHARED/cache/argocd-install-$ARGOCD_VERSION.yaml"
ARGOCD_PASSWORD="argomissions"
GITEA_USER="player"
GITEA_PASSWORD="argomissions"
GITEA_ORG="platform"
GITEA_URL="http://localhost:$GIT_PORT"
ARGOCD_ADDR="localhost:$ARGOCD_PORT"
ARGOCD_CONFIG="${AM_ARGOCD_CONFIG:-$SHARED/argocd/config}"
IMAGES=(nginx:1.27-alpine nginxinc/nginx-unprivileged:1.27-alpine busybox:1.36 curlimages/curl:8.10.1
        traefik/whoami:v1.10 hashicorp/http-echo:1.0)

mkdir -p "$SHARED/cache" "$(dirname "$ARGOCD_CONFIG")" "$(dirname "$KUBECONFIG")"
say() { echo "▶ $*"; }

create_cluster() {
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    say "kind cluster '$CLUSTER' already exists"
    kind get kubeconfig --name "$CLUSTER" >"$KUBECONFIG"
  else
    say "creating kind cluster '$CLUSTER' (about a minute)"
    sed -e "s/hostPort: 9080/hostPort: $ARGOCD_PORT/" -e "s/hostPort: 3300/hostPort: $GIT_PORT/" \
        -e "s/hostPort: 2223/hostPort: $SSH_PORT/" "$ROOT/infra/kind-config.yaml" \
      | kind create cluster --name "$CLUSTER" --config - --kubeconfig "$KUBECONFIG"
  fi
  kubectl config use-context "kind-$CLUSTER" >/dev/null
}

node_pull() {
  local node; node="$CLUSTER-control-plane"
  for img in "$@"; do
    docker exec "$node" crictl inspecti "$img" >/dev/null 2>&1 || docker exec "$node" crictl pull "$img" >/dev/null
  done
}

preload_images() {
  say "pulling mission images into the node"
  node_pull "${IMAGES[@]}"
}

install_gitea() {
  say "installing Gitea"
  node_pull gitea/gitea:28.4.0-rootless
  sed -e "s#http://localhost:3300/#http://localhost:$GIT_PORT/#" -e "s/value: \"2223\"/value: \"$SSH_PORT\"/" \
    "$ROOT/infra/gitea.yaml" | kubectl apply -f - >/dev/null
  kubectl -n gitea rollout status deploy/gitea --timeout=300s >/dev/null
  for _ in $(seq 1 60); do curl -fsS "$GITEA_URL/api/healthz" >/dev/null 2>&1 && break; sleep 2; done
  kubectl -n gitea exec deploy/gitea -- gitea admin user create --username "$GITEA_USER" \
    --password "$GITEA_PASSWORD" --email "$GITEA_USER@argomissions.local" --admin \
    --must-change-password=false >/dev/null 2>&1 || true
  curl -fsS -u "$GITEA_USER:$GITEA_PASSWORD" "$GITEA_URL/api/v1/orgs/$GITEA_ORG" >/dev/null 2>&1 \
    || curl -fsS -u "$GITEA_USER:$GITEA_PASSWORD" -H 'Content-Type: application/json' \
         -d "{\"username\":\"$GITEA_ORG\",\"visibility\":\"public\"}" "$GITEA_URL/api/v1/orgs" >/dev/null
  curl -fsS -u "$GITEA_USER:$GITEA_PASSWORD" "$GITEA_URL/api/v1/orgs/$GITEA_ORG" >/dev/null \
    || { echo "❌ Gitea org '$GITEA_ORG' could not be created"; exit 1; }
  say "Gitea ready at $GITEA_URL (user $GITEA_USER / $GITEA_PASSWORD, org $GITEA_ORG)"
}

install_argocd() {
  say "installing Argo CD $ARGOCD_VERSION"
  if [ ! -s "$ARGOCD_MANIFEST" ]; then
    curl -fsSL -o "$ARGOCD_MANIFEST.tmp" \
      "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
    mv "$ARGOCD_MANIFEST.tmp" "$ARGOCD_MANIFEST"
  fi
  kubectl get ns argocd >/dev/null 2>&1 || kubectl create namespace argocd >/dev/null
  kubectl apply --server-side --force-conflicts -n argocd -f "$ARGOCD_MANIFEST" >/dev/null
  sed "s#http://localhost:9080#http://$ARGOCD_ADDR#" "$ROOT/engine/baseline/argocd-cm.yaml" \
    | kubectl apply --server-side --force-conflicts -f - >/dev/null
  kubectl apply --server-side --force-conflicts -f "$ROOT/engine/baseline/argocd-rbac-cm.yaml" \
    -f "$ROOT/engine/baseline/argocd-cmd-params-cm.yaml" >/dev/null
  # Fixed admin password so the UI and CLI login are predictable.
  local hash; hash="$(argocd account bcrypt --password "$ARGOCD_PASSWORD")"
  kubectl -n argocd patch secret argocd-secret --type merge -p "{\"stringData\":{\"admin.password\":\"$hash\",\"admin.passwordMtime\":\"$(date -u +%FT%TZ)\"}}" >/dev/null
  kubectl -n argocd delete secret argocd-initial-admin-secret --ignore-not-found >/dev/null
  kubectl -n argocd patch svc argocd-server -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30080},{"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}' >/dev/null
  # repo-server caches branch → commit lookups for ARGOCD_RECONCILIATION_TIMEOUT (default 3m), but the
  # stock manifest only wires that variable into the controller. Wire it into repo-server too, so a
  # push shows up within timeout.reconciliation (60s) instead of ~3 minutes.
  if ! kubectl -n argocd get deploy argocd-repo-server -o json | jq -e '.spec.template.spec.containers[0].env[] | select(.name=="ARGOCD_RECONCILIATION_TIMEOUT")' >/dev/null; then
    kubectl -n argocd patch deploy argocd-repo-server --type json -p '[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"ARGOCD_RECONCILIATION_TIMEOUT","valueFrom":{"configMapKeyRef":{"name":"argocd-cm","key":"timeout.reconciliation","optional":true}}}}]' >/dev/null
  fi
  # No SSO in this game; dex only costs memory.
  kubectl -n argocd scale deploy argocd-dex-server --replicas=0 >/dev/null
  kubectl -n argocd rollout restart deploy/argocd-server deploy/argocd-repo-server deploy/argocd-applicationset-controller >/dev/null
  kubectl -n argocd rollout restart statefulset/argocd-application-controller >/dev/null
  for r in statefulset/argocd-application-controller deploy/argocd-server deploy/argocd-repo-server \
           deploy/argocd-redis deploy/argocd-applicationset-controller deploy/argocd-notifications-controller; do
    kubectl -n argocd rollout status "$r" --timeout=600s >/dev/null
  done
  for _ in $(seq 1 30); do kubectl -n argocd get appproject default >/dev/null 2>&1 && break; sleep 2; done
  kubectl apply --server-side --force-conflicts -f "$ROOT/engine/baseline/default-project.yaml" >/dev/null
  say "Argo CD ready at http://$ARGOCD_ADDR (admin / $ARGOCD_PASSWORD)"
}

login() {
  for _ in $(seq 1 30); do curl -fsS "http://$ARGOCD_ADDR/healthz" >/dev/null 2>&1 && break; sleep 2; done
  # argocd-server answers /healthz before its gRPC side is ready (busy machines): retry the login.
  for i in $(seq 1 20); do
    env -u ARGOCD_OPTS argocd login "$ARGOCD_ADDR" --plaintext --username admin --password "$ARGOCD_PASSWORD" \
      --name argomissions --config "$ARGOCD_CONFIG" >/dev/null 2>&1 && break
    [ "$i" = 20 ] && { echo "❌ argocd login failed"; exit 1; }
    sleep 3
  done
  say "argocd CLI logged in (config $ARGOCD_CONFIG)"
}

status() {
  echo "cluster:  $(kind get clusters 2>/dev/null | grep -x "$CLUSTER" || echo missing)"
  kubectl -n argocd get pods 2>/dev/null || true
  kubectl -n gitea get pods 2>/dev/null || true
  curl -fsS "$GITEA_URL/api/healthz" >/dev/null 2>&1 && echo "gitea:    $GITEA_URL ok" || echo "gitea:    not reachable"
  curl -fsS "http://$ARGOCD_ADDR/healthz" >/dev/null 2>&1 && echo "argocd:   http://$ARGOCD_ADDR ok" || echo "argocd:   not reachable"
}

case "$CMD" in
  create) create_cluster; preload_images; install_gitea; install_argocd; login ;;
  argocd) install_argocd; login ;;
  gitea)  install_gitea ;;
  login)  login ;;
  status) status ;;
  delete) kind delete cluster --name "$CLUSTER"; rm -f "$KUBECONFIG" "$ARGOCD_CONFIG" ;;
  *) echo "usage: $0 create|argocd|gitea|login|status|delete" >&2; exit 1 ;;
esac
