#!/bin/bash
set -uo pipefail
source "$AM_LIB"

bad=0
bad() { echo "❌ $1"; bad=$((bad + 1)); }

APP=stockroom-db-v2
NS=stockroom
am_app_exists "$APP" || { echo "❌ Application '$APP' does not exist (it must stay, not be deleted)"; exit 1; }
[ "$(am_app "$APP" '{.spec.source.path}')" = chart ] || bad "Application '$APP' no longer deploys the Helm chart"

# ── manifest generation ─────────────────────────────────────────────────────
if am_app_conditions "$APP" | grep -q ComparisonError; then
  bad "Application '$APP' cannot render its manifests: $(am_app_conditions "$APP" | grep ComparisonError | head -1 | cut -c1-200)"
fi

# ── the sync: Argo CD itself deployed the head ──────────────────────────────
sync="$(am_app_sync "$APP")"; rev="$(am_app_rev "$APP")"; head="$(am_repo_head stockroom-db)"
oprev="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"; op="$(am_app_op "$APP")"
if [ "$sync" != Synced ]; then
  bad "Application '$APP' is ${sync:-Unknown} (the chart is not what runs)"
elif [ "$rev" != "$head" ]; then
  bad "Application '$APP' is synced to ${rev:0:7}, but stockroom-db/main is at ${head:0:7}"
elif [ "$(am_app_health "$APP")" != Healthy ]; then
  bad "Application '$APP' health is $(am_app_health "$APP")"
elif [ "$op" != Succeeded ] || [ "$oprev" != "$head" ]; then
  bad "The last sync of '$APP' is ${op:-missing} at ${oprev:0:7}: nobody has deployed the chart at $head"
else
  am_ok "Application '$APP' is Synced and Healthy, deployed at stockroom-db@${head:0:7}"
fi

# ── object names: the consumers' names ──────────────────────────────────────
for kind in svc deploy; do
  kubectl -n $NS get "$kind" stockroom-db >/dev/null 2>&1 || bad "$kind stockroom-db does not exist in namespace $NS: consumers call it by that name"
done
leftover="$(kubectl -n $NS get svc,deploy -o name 2>/dev/null | grep -v '/stockroom-db$' || true)"
[ -z "$leftover" ] || bad "Objects renamed by the migration are still there: $(echo $leftover)"
tid="$(am_jsonpath deploy/stockroom-db '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' $NS)"
case "$tid" in "$APP":*) ;; *) bad "Deployment stockroom-db is not managed by '$APP'";; esac

# ── the data ────────────────────────────────────────────────────────────────
kubectl -n argocd get configmap argomissions-stockroom-baseline -o jsonpath='{.data.pvc-uid}' >"$AM_TMP/uid" 2>/dev/null || true
was="$(cat "$AM_TMP/uid")"
now="$(am_jsonpath pvc/stockroom-db-data '{.metadata.uid}' $NS)"
del="$(am_jsonpath pvc/stockroom-db-data '{.metadata.deletionTimestamp}' $NS)"
if [ -z "$now" ]; then
  bad "PersistentVolumeClaim stockroom-db-data is gone: the inventory data went with it"
elif [ "$now" != "$was" ]; then
  bad "PersistentVolumeClaim stockroom-db-data is a new claim, not the one that held the data"
elif [ -n "$del" ]; then
  bad "PersistentVolumeClaim stockroom-db-data is being deleted"
else
  am_ok "The original data volume is still there"
fi
claim="$(am_jsonpath deploy/stockroom-db '{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' $NS)"
[ "$claim" = stockroom-db-data ] || bad "Deployment stockroom-db stores its data on claim '${claim:-none}', not on the volume that holds the inventory"
strays="$(kubectl -n $NS get pvc -o name 2>/dev/null | grep -v '/stockroom-db-data$' || true)"
[ -z "$strays" ] || bad "An extra, empty volume claim exists: $(echo $strays)"

# ── what the service answers ────────────────────────────────────────────────
if [ "$(am_ready_replicas stockroom-db $NS)" -ge 1 ]; then
  body="$(am_http http://stockroom-db.$NS $NS 3)" || body="(no answer)"
  [ "$body" = "stockroom-db prod 3.0" ] || bad "Service stockroom-db answers '$body', not the production configuration"
  body="$(am_http http://stockroom-db.$NS/seq $NS 3)" || body="(no answer)"
  [ "$body" = "seq=4821 shipments=1873" ] || bad "Service stockroom-db serves '$body': the inventory data is not behind it"
else
  bad "Deployment stockroom-db has no ready pods"
fi

[ "$bad" -eq 0 ] || { echo "❌ $bad problem(s) left after the migration"; exit 1; }
am_pass "The chart runs under the old names, with production values, on the original data volume"
