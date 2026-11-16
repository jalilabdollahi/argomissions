#!/bin/bash
set -uo pipefail
source "$AM_LIB"

ROOT=stormwatch-root
NS=stormwatch
fails=0
bad() { echo "❌ $*"; fails=$((fails+1)); }
good() { am_ok "$*"; }

for a in $ROOT sw-ingest sw-alerts; do
  am_app_exists "$a" || am_fail "Application '$a' does not exist in namespace argocd"
done
head="$(am_repo_head stormwatch)"
am_repo_checkout stormwatch "$AM_TMP/git" >/dev/null 2>&1 || am_fail "cannot clone stormwatch"

# ── Hand-edited child ───────────────────────────────────────────────────────────
rev="$(am_app sw-alerts '{.spec.source.targetRevision}')"
case "$rev" in
  main|HEAD|refs/heads/main) good "Children: sw-alerts follows $rev again" ;;
  *) bad "Children: Application sw-alerts is pinned to '${rev:0:12}' by hand, so it serves an old release while Git has moved on" ;;
esac
for a in $ROOT sw-ingest sw-alerts; do
  s="$(am_app_sync "$a")"; h="$(am_app_health "$a")"; r="$(am_app_rev "$a")"
  if [ "$s" != Synced ] || [ "$h" != Healthy ] || [ "$r" != "$head" ]; then
    bad "Platform: Application $a is ${s:-?}/${h:-?} at ${r:0:7} (head ${head:0:7}) $(am_app_conditions "$a" | head -1 | cut -c1-140)"
  fi
done
for a in sw-ingest sw-alerts; do
  tid="$(am_app "$a" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}')"
  case "$tid" in "$ROOT:argoproj.io/Application:argocd/$a") ;; *) bad "Children: Application $a is not managed by $ROOT" ;; esac
done

# ── Self-heal ───────────────────────────────────────────────────────────────────
[ "$(am_app $ROOT '{.spec.syncPolicy.automated.selfHeal}')" = true ] \
  || bad "Self-heal: $ROOT is synced by hand and does not undo hand edits of its children (a manual change to an Application stays until somebody notices)"
for a in sw-ingest sw-alerts; do
  f="$AM_TMP/git/apps/${a#sw-}.yaml"
  [ "$(am_yaml_get "$f" spec.syncPolicy.automated.selfHeal)" = true ] \
    || bad "Self-heal: in Git, Application $a does not heal drift of its workloads"
  [ "$(am_app "$a" '{.spec.syncPolicy.automated.selfHeal}')" = true ] \
    || bad "Self-heal: the live Application $a does not heal drift of its workloads"
done
b="$(am_http http://sw-ingest.$NS $NS 2 2>/dev/null)"
[ "$b" = "sw-ingest v2.1" ] || bad "Drift: Service sw-ingest answers '${b:-nothing}' instead of 'sw-ingest v2.1' (a hand edit of its Deployment is still live)"

# ── The mesh controller's annotation ────────────────────────────────────────────
am_yaml_get "$AM_TMP/git/apps/ingest.yaml" spec.ignoreDifferences >"$AM_TMP/ign.json"
covered="$(jq '[ (. // [])[] | select((.group // "apps") == "apps" and (.kind // "Deployment") == "Deployment")
    | select(((.jsonPointers // []) | index("/metadata/annotations/mesh.argomissions.io~1epoch")) != null
          or ((.jqPathExpressions // []) | map(select(contains("mesh.argomissions.io/epoch"))) | length) > 0
          or ((.managedFieldsManagers // []) | index("mesh-stamper")) != null) ] | length' "$AM_TMP/ign.json")"
[ "${covered:-0}" -ge 1 ] || bad "Mutation: in Git, Application sw-ingest has no rule for the epoch annotation the mesh controller keeps rewriting: it is OutOfSync again with every stamp"
live_cov="$(am_app sw-ingest '{.spec.ignoreDifferences}' | grep -c 'mesh' || true)"
[ "${live_cov:-0}" -ge 1 ] || bad "Mutation: the live Application sw-ingest does not ignore the mesh controller's annotation"
[ "$(kubectl -n stormwatch-mesh get deploy mesh-stamper -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = 1 ] \
  || bad "Mutation: the mesh team's controller (mesh-stamper in namespace stormwatch-mesh) is not running: the conflict was removed, not resolved"
e1="$(am_jsonpath deploy/sw-ingest '{.metadata.annotations.mesh\.argomissions\.io/epoch}' $NS)"
sleep 12
e2="$(am_jsonpath deploy/sw-ingest '{.metadata.annotations.mesh\.argomissions\.io/epoch}' $NS)"
[ -n "$e2" ] && [ "$e1" != "$e2" ] || bad "Mutation: the live Deployment is no longer stamped by the mesh controller ($e1 -> $e2)"
[ "$(am_app_sync sw-ingest)" = Synced ] || bad "Mutation: sw-ingest went $(am_app_sync sw-ingest) when the mesh controller wrote again"

# ── Shared ConfigMap ────────────────────────────────────────────────────────────
owners=()
for pair in sw-ingest:ingest sw-alerts:alerts; do
  c="$(am_yaml_docs_json "$AM_TMP/git/workloads/${pair##*:}" | jq '[.[] | select(.kind=="ConfigMap" and .metadata.name=="thresholds")] | length')"
  [ "$c" -ge 1 ] && owners+=("${pair%%:*}")
done
if [ "${#owners[@]}" -ge 2 ]; then bad "Shared resource: ConfigMap thresholds is defined in the folders of both sw-ingest and sw-alerts in Git"
elif [ "${#owners[@]}" -eq 0 ]; then bad "Shared resource: ConfigMap thresholds is defined in neither folder"
fi
for a in sw-ingest sw-alerts; do
  am_app_conditions "$a" | grep -q '^SharedResourceWarning' && bad "Shared resource: Application $a reports SharedResourceWarning for ConfigMap thresholds"
done
flags="$(kubectl -n $NS get cm thresholds -o json 2>/dev/null | jq -c '.data // {}')"
[ "$(echo "$flags" | jq -r '.rain_mm')" = 40 ] && [ "$(echo "$flags" | jq -r '.wind_kmh')" = 90 ] \
  || bad "Shared resource: ConfigMap thresholds holds $flags; ingest needs rain_mm=40 and alerts need wind_kmh=90"
if [ "${#owners[@]}" -eq 1 ]; then
  tid="$(am_jsonpath cm/thresholds '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' $NS)"
  case "$tid" in "${owners[0]}":*) ;; *) bad "Shared resource: ConfigMap thresholds is tracked as '${tid:-<none>}', not by ${owners[0]}" ;; esac
fi

b="$(am_http http://sw-alerts.$NS $NS 2 2>/dev/null)"
[ "$b" = "sw-alerts v1.1" ] || bad "Platform: Service sw-alerts answers '${b:-nothing}' instead of 'sw-alerts v1.1'"

[ "$fails" = 0 ] || { echo "   $fails problem(s) left"; exit 1; }
am_pass "the storm is over: children follow Git, drift heals, the mesh controller and Argo CD coexist"
