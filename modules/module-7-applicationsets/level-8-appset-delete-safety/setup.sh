#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed kiosk-web "$LEVEL_DIR/repo" "kiosk-web v2.4 manifests"
cp "$LEVEL_DIR/assets/appset-new.yaml" "$SANDBOX/kiosk-fleet-appset.yaml"
kubectl apply -f "$LEVEL_DIR/assets/appset-old.yaml" >/dev/null

for r in north south east; do
  am_wait_app "kiosk-$r" sync=Synced health=Healthy --timeout 150 \
    || { echo "setup: kiosk-$r did not become healthy"; exit 1; }
  kubectl -n "kiosk-$r" rollout status deploy/kiosk-web --timeout=90s >/dev/null
done

# Remember what is running right now: the validator compares UIDs against this (hidden from the player in a labelled ConfigMap).
args=()
for r in north south east; do
  args+=("--from-literal=deploy-$r=$(am_jsonpath deploy/kiosk-web '{.metadata.uid}' "kiosk-$r")")
  args+=("--from-literal=svc-$r=$(am_jsonpath svc/kiosk-web '{.metadata.uid}' "kiosk-$r")")
done
kubectl -n argocd delete configmap argomissions-kiosk-baseline --ignore-not-found >/dev/null
kubectl -n argocd create configmap argomissions-kiosk-baseline "${args[@]}" >/dev/null
kubectl -n argocd label configmap argomissions-kiosk-baseline argomissions.io/cleanup=true >/dev/null

am_setup_assert "the old ApplicationSet owns the apps" \
  bash -c 'kubectl -n argocd get app kiosk-north -o jsonpath="{.metadata.ownerReferences[0].name}" | grep -qx kiosk-apps'
am_setup_assert "apps carry the resources finalizer" \
  bash -c 'kubectl -n argocd get app kiosk-north -o jsonpath="{.metadata.finalizers}" | grep -q resources-finalizer'
