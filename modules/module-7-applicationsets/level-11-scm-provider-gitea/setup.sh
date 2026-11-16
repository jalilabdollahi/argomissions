#!/bin/bash
set -euo pipefail
source "$AM_LIB"

for r in mesh-pinger mesh-quill mesh-ember wiki-notes; do
  am_repo_seed "$r" "$LEVEL_DIR/repos/$r" "initial import" >/dev/null 2>&1
done

# An access token for the SCM generator (unique name per run; tokens of earlier runs are removed).
for old in $(am_gitea GET /users/player/tokens | jq -r '.[].name | select(startswith("argomissions-scm-"))'); do
  am_gitea DELETE "/users/player/tokens/$old" >/dev/null 2>&1 || true
done
token="$(am_gitea POST /users/player/tokens \
  "{\"name\":\"argomissions-scm-$(date +%s)-$RANDOM\",\"scopes\":[\"read:repository\",\"read:organization\",\"read:user\",\"read:issue\"]}" \
  | jq -r .sha1)"
[ -n "$token" ] && [ "$token" != null ] || { echo "setup: could not create a Gitea token"; exit 1; }
kubectl -n argocd delete secret gitea-scm-token --ignore-not-found >/dev/null
kubectl -n argocd create secret generic gitea-scm-token --from-literal=token="$token" >/dev/null
kubectl -n argocd label secret gitea-scm-token argomissions.io/cleanup=true >/dev/null

cp "$LEVEL_DIR/assets/appset.yaml" "$SANDBOX/mesh-appset.yaml"
kubectl apply -f "$LEVEL_DIR/assets/appset.yaml" >/dev/null

errored() { kubectl -n argocd get applicationset mesh-fleet -o json \
  | jq -e '[.status.conditions[]? | select(.type=="ErrorOccurred" and .status=="True" and (.message | contains("access-token")))] | length > 0'; }
am_wait 60 errored || { echo "setup: the ApplicationSet did not report the token error"; exit 1; }
am_setup_assert "no Application generated" bash -c '[ "$(kubectl -n argocd get applications -o name | wc -l | tr -d "[:space:]")" = 0 ]'
