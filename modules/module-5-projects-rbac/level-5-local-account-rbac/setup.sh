#!/bin/bash
set -euo pipefail
source "$AM_LIB"

ci_argocd() { ARGOCD_OPTS="" command argocd --config "$AM_TMP/ci" --plaintext --server "$AM_ARGOCD_ADDR" "$@"; }

# local-account material lives in argocd-secret; make the level re-runnable
for k in accounts.ci-bot.password accounts.ci-bot.passwordMtime accounts.ci-bot.tokens; do
  kubectl -n argocd patch secret argocd-secret --type json -p "[{\"op\":\"remove\",\"path\":\"/data/$k\"}]" >/dev/null 2>&1 || true
done

am_repo_seed webshop "$LEVEL_DIR/repo" "webshop: shop front end and staff portal"
kubectl create namespace shop >/dev/null
kubectl create namespace people >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/projects.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/apps.yaml"

# the account exists (apiKey + login) but argocd-rbac-cm grants it nothing
kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"accounts.ci-bot":"apiKey, login"}}' >/dev/null
am_wait 60 am_argocd account update-password --account ci-bot --current-password "$AM_ARGOCD_PASSWORD" --new-password ci-bot-pass-123 \
  || { echo "setup: could not set the ci-bot password"; exit 1; }
am_wait 60 ci_argocd login "$AM_ARGOCD_ADDR" --username ci-bot --password ci-bot-pass-123 \
  || { echo "setup: ci-bot cannot log in"; exit 1; }

am_wait_app shop-web sync=OutOfSync --timeout 90 || { echo "setup: shop-web not compared"; exit 1; }
if ci_argocd app sync shop-web >"$AM_TMP/sync.txt" 2>&1; then echo "setup: ci-bot could sync"; exit 1; fi
grep -q "permission denied" "$AM_TMP/sync.txt" || { echo "setup: unexpected CI failure"; cat "$AM_TMP/sync.txt"; exit 1; }
am_setup_assert "policy still empty" bash -c '[ -z "$(kubectl -n argocd get cm argocd-rbac-cm -o jsonpath="{.data.policy\.csv}")" ]'
