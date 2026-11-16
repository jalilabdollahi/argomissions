#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=host-registry
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# the objective needs the whole export: it must still be in Git
am_repo_checkout host-registry "$AM_TMP/git" || am_fail "cannot clone repo host-registry"
git_json="$(am_yaml_docs_json "$AM_TMP/git/deploy")"
git_size="$(echo "$git_json" | jq '[.[] | select(.kind=="ConfigMap" and .metadata.name=="host-inventory")][0].data["hosts.txt"] // "" | length')"
[ "$git_size" -gt 262144 ] \
  || am_fail "ConfigMap host-inventory in Git holds only $git_size bytes of hosts.txt; the full export is needed"
am_ok "Git still carries the full host export ($git_size bytes)"

# the way it is applied must be part of the declared state (Application spec or the manifest in Git)
opt_app="$(am_app "$APP" '{.spec.syncPolicy.syncOptions}' | grep -c 'ServerSideApply=true')"
opt_git="$(echo "$git_json" | jq '[.[] | select(.kind=="ConfigMap" and .metadata.name=="host-inventory")][0].metadata.annotations["argocd.argoproj.io/sync-options"] // "" | contains("ServerSideApply=true")')"
{ [ "$opt_app" -ge 1 ] || [ "$opt_git" = true ]; } \
  || am_fail "ConfigMap host-inventory is applied the way that failed: nothing in the Application or in Git changes how it is applied"
am_ok "Server-side apply is declared"

am_require_app_at_head "$APP" host-registry
head="$(am_repo_head host-registry)"
[ "$(am_app "$APP" '{.status.operationState.phase}')" = Succeeded ] \
  && [ "$(am_app "$APP" '{.status.operationState.syncResult.revision}')" = "$head" ] \
  || am_fail "The last sync operation of '$APP' did not succeed at ${head:0:7}"

live_size="$(kubectl -n netops get cm host-inventory -o json 2>/dev/null | jq '.data["hosts.txt"] // "" | length')"
[ "${live_size:-0}" = "$git_size" ] || am_fail "Live ConfigMap netops/host-inventory holds ${live_size:-0} bytes of hosts.txt, Git has $git_size"
live_last="$(kubectl -n netops get cm host-inventory -o json | jq -r '.data["hosts.txt"] | split("\n") | map(select(. != "")) | last')"
[ "$live_last" = "10.0.35.39 host-08999.corp.internal zone-9" ] || am_fail "Live ConfigMap ends with '$live_last'"
[ -n "$(am_jsonpath cm/host-inventory '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' netops)" ] \
  || am_fail "ConfigMap netops/host-inventory is not managed by Argo CD"
am_ok "Live ConfigMap holds the full export ($live_size bytes), managed by Argo CD"

am_wait_rollout deploy/host-registry netops 60s
body="$(am_http http://host-registry.netops netops)" || am_fail "Service host-registry in namespace netops does not answer"
[ "$body" = "host-registry v1.0" ] || am_fail "Service host-registry answers '$body'"
am_pass "host-registry serves the full inventory, applied by Argo CD"
