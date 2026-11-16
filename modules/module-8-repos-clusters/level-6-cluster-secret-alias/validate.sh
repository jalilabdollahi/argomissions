#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=boarding-pass
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# The cluster secret that registers the destination called "staging"
secret="$(kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster -o json \
  | jq -c '[.items[] | select((.data.name // "" | @base64d) == "staging")] | first // empty')"
[ -n "$secret" ] || am_fail "No cluster secret registers a destination named 'staging' (argocd cluster list)"
server="$(jq -r '.data.server | @base64d' <<<"$secret")"
cfg="$(jq -r '.data.config // "" | @base64d' <<<"$secret")"
[ -n "$cfg" ] || cfg='{}'

dest_name="$(am_app "$APP" '{.spec.destination.name}')"
dest_server="$(am_app "$APP" '{.spec.destination.server}')"
dest_ns="$(am_app "$APP" '{.spec.destination.namespace}')"
if [ "$dest_name" != staging ] && [ "$dest_server" != "$server" ]; then
  am_fail "Application '$APP' deploys to '${dest_name:-$dest_server}', not to the cluster registered as 'staging'"
fi
[ "$dest_ns" = boarding-stg ] || am_fail "Application '$APP' deploys to namespace '${dest_ns:-<none>}', not 'boarding-stg'"
am_ok "Application '$APP' targets the 'staging' cluster, namespace boarding-stg"

[ "$(jq -r '.tlsClientConfig.insecure // false' <<<"$cfg")" != true ] \
  || am_fail "Cluster 'staging' is registered with TLS verification switched off"
[ -n "$(jq -r '.tlsClientConfig.caData // empty' <<<"$cfg")" ] \
  || am_fail "Cluster 'staging' has no CA certificate to verify the API server with"
sub="$(jq -r '.bearerToken // empty' <<<"$cfg" | "$AM_PYTHON" -c '
import sys, base64, json
t = sys.stdin.read().strip().split(".")
try:
    print(json.loads(base64.urlsafe_b64decode(t[1] + "=" * (-len(t[1]) % 4))).get("sub", ""))
except Exception:
    print("")')"
[ "$sub" = "system:serviceaccount:boarding-stg:argocd-deployer" ] \
  || am_fail "Cluster 'staging' does not authenticate as the namespace-scoped deployer ServiceAccount (token subject: '${sub:-none}')"
am_ok "Cluster 'staging' verifies TLS and uses the argocd-deployer ServiceAccount"

# The connection state is cached and refreshed every ~10s; right after a reset it is empty for a while.
status=""
for _ in $(seq 1 30); do
  status="$(am_argocd cluster get staging -o json 2>/dev/null | jq -r '.connectionState.status // empty')"
  [ -n "$status" ] && break
  sleep 3
done
[ "$status" = Successful ] || am_fail "Argo CD cannot connect to cluster 'staging' (connection status: ${status:-unknown})"
am_ok "Argo CD connects to cluster 'staging'"

am_require_app_at_head "$APP" boarding-pass
tracking="$(am_jsonpath deploy/boarding-pass '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' boarding-stg)"
[ -n "$tracking" ] || am_fail "Deployment boarding-stg/boarding-pass is not managed by Argo CD"
[ "$(am_ready_replicas boarding-pass boarding-stg)" -ge 2 ] || am_fail "Deployment boarding-pass has fewer than 2 ready pods"
body="$(am_http http://boarding-pass.boarding-stg boarding-stg)" || am_fail "Service boarding-pass in boarding-stg does not answer"
[ "$body" = "boarding-pass v3.1" ] || am_fail "Service boarding-pass answers '$body'"
am_pass "boarding-pass runs on the 'staging' cluster, authenticated and verified"
