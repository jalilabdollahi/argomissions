#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed pulse-web "$LEVEL_DIR/repo" "pulse-web main" >/dev/null 2>&1
for b in checkout-redesign legacy-cleanup wip-search; do
  am_repo_branch pulse-web "$b" >/dev/null 2>&1
  BRANCH="$b" am_repo_commit pulse-web "$LEVEL_DIR/assets/branch-$b" "Work on $b" >/dev/null 2>&1
done

label_id="$(am_gitea POST /repos/platform/pulse-web/labels '{"name":"deploy-preview","color":"#1d76db"}' | jq -r .id)"
declare -A pr
for b in checkout-redesign legacy-cleanup wip-search; do
  pr[$b]="$(am_gitea POST /repos/platform/pulse-web/pulls "{\"head\":\"$b\",\"base\":\"main\",\"title\":\"$b\"}" | jq -r .number)"
done
am_gitea POST "/repos/platform/pulse-web/issues/${pr[checkout-redesign]}/labels" "{\"labels\":[$label_id]}" >/dev/null
am_gitea POST "/repos/platform/pulse-web/issues/${pr[legacy-cleanup]}/labels" "{\"labels\":[$label_id]}" >/dev/null
am_gitea PATCH "/repos/platform/pulse-web/pulls/${pr[legacy-cleanup]}" '{"state":"closed"}' >/dev/null

for old in $(am_gitea GET /users/player/tokens | jq -r '.[].name | select(startswith("argomissions-pr-"))'); do
  am_gitea DELETE "/users/player/tokens/$old" >/dev/null 2>&1 || true
done
token="$(am_gitea POST /users/player/tokens \
  "{\"name\":\"argomissions-pr-$(date +%s)-$RANDOM\",\"scopes\":[\"read:repository\",\"read:organization\",\"read:user\",\"read:issue\"]}" \
  | jq -r .sha1)"
[ -n "$token" ] && [ "$token" != null ] || { echo "setup: could not create a Gitea token"; exit 1; }
kubectl -n argocd delete secret gitea-pr-token --ignore-not-found >/dev/null
kubectl -n argocd create secret generic gitea-pr-token --from-literal=token="$token" >/dev/null
kubectl -n argocd label secret gitea-pr-token argomissions.io/cleanup=true >/dev/null

cp "$LEVEL_DIR/assets/appset.yaml" "$SANDBOX/pulse-previews-appset.yaml"
kubectl apply -f "$LEVEL_DIR/assets/appset.yaml" >/dev/null

generated() { kubectl -n argocd get applicationset pulse-previews -o json \
  | jq -e '[.status.conditions[]? | select(.type=="ParametersGenerated" and .status=="True")] | length == 1'; }
am_wait 60 generated || { echo "setup: the ApplicationSet did not generate parameters"; exit 1; }
sleep 5
am_setup_assert "no Application generated" bash -c '[ "$(kubectl -n argocd get applications -o name | wc -l | tr -d "[:space:]")" = 0 ]'
