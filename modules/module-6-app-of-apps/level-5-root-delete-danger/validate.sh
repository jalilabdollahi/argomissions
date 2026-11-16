#!/bin/bash
set -uo pipefail
source "$AM_LIB"

ROOT=inventory-root

# 1. The service is back, owned by Argo CD, and nothing else was disturbed.
am_app_exists stock-api || am_fail "Application 'stock-api' does not exist: the inventory API is still gone"
am_require_app_at_head "$ROOT" inventory-gitops
for c in stock-api stock-sync; do
  [ "$(am_app_sync "$c")" = Synced ] && [ "$(am_app_health "$c")" = Healthy ] \
    || am_fail "Application '$c' is $(am_app_sync "$c")/$(am_app_health "$c") (expected Synced/Healthy)"
done
am_ok "$ROOT, stock-api and stock-sync are Synced and Healthy"
for pair in stock-api:inventory-stock:"stock-api v6.2" stock-sync:inventory-sync:"stock-sync v3.4"; do
  IFS=: read -r svc ns want <<<"$pair"
  body="$(am_http "http://$svc.$ns" "$ns")" || am_fail "Service $svc in namespace $ns does not answer"
  [ "$body" = "$want" ] || am_fail "Service $svc answers '$body'"
done
base="$(kubectl -n inventory-sync get configmap recovery-baseline -o jsonpath='{.data.stock-sync-uid}' 2>/dev/null)"
now="$(kubectl -n inventory-sync get deploy stock-sync -o jsonpath='{.metadata.uid}' 2>/dev/null)"
[ -n "$base" ] && [ "$base" = "$now" ] || am_fail "Deployment stock-sync was deleted and recreated during the recovery (a service that was never broken restarted)"
am_ok "Both services answer; stock-sync was never restarted"

# 2. History kept: the mistake stays in the log, it is corrected by a newer commit.
work="$AM_TMP/repo"
am_repo_checkout inventory-gitops "$work" || am_fail "Cannot clone inventory-gitops"
git -C "$work" log --format=%s | grep -qx "cleanup: drop unused manifests" \
  || am_fail "The history of inventory-gitops/main was rewritten: the commit that caused the incident is gone from the log"

# 3. Protection in Git (and live): every child survives a removal from Git and the deletion of the root.
am_yaml_docs_json "$work/apps" >"$AM_TMP/docs.json"
"$AM_PYTHON" - "$AM_TMP/docs.json" <<'PY' || exit 1
import json, sys
docs = json.load(open(sys.argv[1]))
apps = {d["metadata"]["name"]: d for d in docs if d.get("kind") == "Application"}
for need in ("stock-api", "stock-sync"):
    if need not in apps:
        print("❌ Application %s is not in the root's folder in Git" % need); sys.exit(1)
for name, d in sorted(apps.items()):
    ann = (d.get("metadata") or {}).get("annotations") or {}
    opts = {o.strip() for o in str(ann.get("argocd.argoproj.io/sync-options", "")).split(",")}
    missing = [o for o in ("Prune=false", "Delete=false") if o not in opts]
    if missing:
        print("❌ In Git, Application %s is not protected against %s" % (name, "removal from Git" if "Prune=false" in missing else "deletion of the root"))
        sys.exit(1)
print("✅ Every child Application in Git is protected against being pruned or deleted with the root")
PY
for c in stock-api stock-sync; do
  opts="$(am_app "$c" '{.metadata.annotations.argocd\.argoproj\.io/sync-options}')"
  case "$opts" in *Prune=false*Delete=false*|*Delete=false*Prune=false*) ;; *) am_fail "The live Application '$c' is not protected yet (sync-options '$opts')" ;; esac
done
am_pass "stock-api is back from Git history and every child now survives the next accident"
