#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed rewards-engine "$LEVEL_DIR/repo" "rewards-engine v1"
kubectl create namespace rewards >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh rewards-engine
am_wait_app rewards-engine sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: rewards-engine did not become healthy"; exit 1; }

kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"accounts.mira":"login"}}' >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/rbac.yaml" >/dev/null
sleep 3
am_argocd account update-password --account mira --current-password "$AM_ARGOCD_PASSWORD" --new-password mira-pw-4821 >/dev/null

# The broken state: mira can edit the Application but is refused on the resources it manages.
api() {  # api METHOD PATH [BODY] -> prints the HTTP status
  local tok; tok="$(curl -s -X POST -H 'Content-Type: application/json' "http://$AM_ARGOCD_ADDR/api/v1/session" \
    -d '{"username":"mira","password":"mira-pw-4821"}' | jq -r .token)"
  curl -s -o /dev/null -w '%{http_code}' -X "$1" -H 'Content-Type: application/json' -H "Authorization: Bearer $tok" \
    "http://$AM_ARGOCD_ADDR/api/v1/applications/rewards-engine$2" ${3:+-d "$3"}
}
can_update() { [ "$(api PATCH "" '{"patch":"{}","patchType":"merge"}')" = 200 ]; }
am_wait 30 can_update || { echo "setup: mira cannot update the application"; exit 1; }
[ "$(api POST "/resource/actions?namespace=rewards&resourceName=rewards-engine&version=v1&kind=Deployment&group=apps" '"restart"')" = 403 ] \
  || { echo "setup: restart should be denied"; exit 1; }
[ "$(api DELETE "/resource?namespace=rewards&resourceName=ghost&version=v1&kind=Pod&group=")" = 403 ] \
  || { echo "setup: pod delete should be denied"; exit 1; }
