#!/bin/bash
set -uo pipefail
source "$AM_LIB"

secret="$(kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster -o json \
  | jq -c '[.items[] | select((.data.name // "" | @base64d) == "regional")] | first // empty')"
[ -n "$secret" ] || am_fail "No cluster secret registers a destination named 'regional' (argocd cluster list)"
server="$(jq -r '.data.server | @base64d' <<<"$secret")"

check_app() {  # check_app APP PATH NAMESPACE
  local app="$1" dname dserver dns
  am_app_exists "$app" || am_fail "Application '$app' does not exist in namespace argocd"
  dname="$(am_app "$app" '{.spec.destination.name}')"; dserver="$(am_app "$app" '{.spec.destination.server}')"
  dns="$(am_app "$app" '{.spec.destination.namespace}')"
  if [ "$dname" != regional ] && [ "$dserver" != "$server" ]; then
    am_fail "Application '$app' no longer deploys to the 'regional' cluster (destination: ${dname:-$dserver})"
  fi
  [ "$dns" = "$3" ] || am_fail "Application '$app' deploys to namespace '${dns:-<none>}', its region needs '$3'"
  [ "$(am_app "$app" '{.spec.source.path}')" = "$2" ] || am_fail "Application '$app' no longer reads folder '$2' of parcel-hub"
}
check_app parcel-hub-eu eu parcel-eu
check_app parcel-hub-us us parcel-us
am_ok "Both Applications target cluster 'regional' and their own region namespace"

scope="$(jq -r '(.data.namespaces // "" | @base64d)' <<<"$secret" | tr ',' '\n' | sed 's/ //g' | grep -v '^$' | sort | paste -sd, -)"
[ -n "$scope" ] || am_fail "Cluster 'regional' has no namespace scope: the namespace-scoped ServiceAccount cannot list cluster-wide resources"
[ "$scope" = "parcel-eu,parcel-us" ] \
  || am_fail "Cluster 'regional' is scoped to '$scope' - it must cover the two region namespaces and nothing else"
sub="$(jq -r '.data.config | @base64d | fromjson | .bearerToken // empty' <<<"$secret" | "$AM_PYTHON" -c '
import sys, base64, json
t = sys.stdin.read().strip().split(".")
try:
    print(json.loads(base64.urlsafe_b64decode(t[1] + "=" * (-len(t[1]) % 4))).get("sub", ""))
except Exception:
    print("")')"
[ "$sub" = "system:serviceaccount:parcel-eu:argocd-regional" ] \
  || am_fail "Cluster 'regional' does not authenticate as the regional deployer ServiceAccount (token subject: '${sub:-none}')"
am_ok "Cluster 'regional' is scoped to parcel-eu and parcel-us with the deployer ServiceAccount"

# The connection state is cached and refreshed every ~10s; right after a reset it is empty for a while.
status=""
for _ in $(seq 1 30); do
  status="$(am_argocd cluster get regional -o json 2>/dev/null | jq -r '.connectionState.status // empty')"
  [ -n "$status" ] && break
  sleep 3
done
[ "$status" = Successful ] || am_fail "Argo CD cannot use cluster 'regional' (connection status: ${status:-unknown})"

am_require_app_at_head parcel-hub-eu parcel-hub
am_require_app_at_head parcel-hub-us parcel-hub
for r in eu us; do
  tracking="$(am_jsonpath deploy/parcel-hub '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' "parcel-$r")"
  [ -n "$tracking" ] || am_fail "Deployment parcel-$r/parcel-hub is not managed by Argo CD"
  body="$(am_http http://parcel-hub.parcel-$r parcel-$r)" || am_fail "Service parcel-hub in parcel-$r does not answer"
  [ "$body" = "parcel-hub $r v2.0" ] || am_fail "Service parcel-hub in parcel-$r answers '$body'"
done
am_pass "parcel-hub runs in both regions through the scoped 'regional' cluster"
