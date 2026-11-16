#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=media-store
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_repo_checkout media-store "$AM_TMP/repo" || am_fail "cannot clone the media-store repo"
docs="$(am_yaml_docs_json "$AM_TMP/repo")"
[ "$(echo "$docs" | jq '[.[] | select(.kind=="PersistentVolumeClaim")] | length')" = 0 ] \
  || am_fail "A PersistentVolumeClaim manifest is still in the media-store repo: the claim was supposed to leave it"
[ "$(echo "$docs" | jq '[.[] | select(.kind=="Deployment" and .metadata.name=="media-store")] | length')" = 1 ] \
  || am_fail "The media-store Deployment is gone from Git: only the claim should have left"
am_ok "the claim's manifest has left the repo, the workload stays"

[ "$(am_app_json "$APP" | jq -r '.spec.syncPolicy.automated.prune // false')" = true ] \
  || am_fail "Application '$APP' no longer prunes: the team wants auto-prune to stay on for everything else"
am_ok "Application '$APP' still prunes automatically"

# the data: same claim as before the move
expected="$(kubectl -n media get configmap storage-audit -o jsonpath='{.data.uploads-pvc-uid}' 2>/dev/null || true)"
[ -n "$expected" ] || am_fail "The storage audit note (ConfigMap storage-audit in namespace media) is missing"
kubectl -n media get pvc uploads >/dev/null 2>&1 \
  || am_fail "PersistentVolumeClaim uploads does not exist in namespace media: the customers' uploads are gone"
[ -z "$(am_jsonpath pvc/uploads '{.metadata.deletionTimestamp}' media)" ] \
  || am_fail "PersistentVolumeClaim uploads is being deleted (Terminating): it will vanish as soon as the pod lets go"
uid="$(am_jsonpath pvc/uploads '{.metadata.uid}' media)"
[ "$uid" = "$expected" ] || am_fail "PersistentVolumeClaim uploads is a different claim now (uid ${uid:0:8}, the audit note says ${expected:0:8}): the data was not preserved"
[ "$(am_jsonpath pvc/uploads '{.status.phase}' media)" = Bound ] || am_fail "PersistentVolumeClaim uploads is not Bound"
am_ok "PersistentVolumeClaim uploads is the original claim, alive and Bound"

am_require_app_at_head "$APP" media-store
am_wait_rollout deploy/media-store media 60s
body="$(am_http http://media-store.media media)" || am_fail "Service media-store in namespace media does not answer"
[ "$body" = "media-store v1.4" ] || am_fail "Service media-store answers '$body'"
am_pass "the claim left Git, the data stayed"
