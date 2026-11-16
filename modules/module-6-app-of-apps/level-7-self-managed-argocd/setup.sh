#!/bin/bash
set -euo pipefail
source "$AM_LIB"

seed="$AM_TMP/seed"
cp -R "$LEVEL_DIR/repo" "$seed"
sed -i.bak "s/__ARGOCD_PORT__/$AM_ARGOCD_PORT/" "$seed/config/argocd-cm.yaml" && rm -f "$seed/config/argocd-cm.yaml.bak"
am_repo_seed argocd-settings "$seed" "argocd-settings: argocd-cm and argocd-rbac-cm"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh argocd-settings
am_wait_app argocd-settings sync=Synced health=Healthy op=Succeeded --timeout 120 || { echo "setup: argocd-settings did not sync"; exit 1; }

# The colleague's edit, and Argo CD reverting it.
cat >"$AM_TMP/edit.json" <<'JSON'
{"data":{"policy.csv":"p, role:auditor, applications, get, */*, allow\np, role:auditor, logs, get, */*, allow\ng, platform-auditors, role:auditor\n# incident access\np, role:oncall, applications, sync, default/*, allow\ng, payments-oncall, role:oncall\n"}}
JSON
kubectl -n argocd patch configmap argocd-rbac-cm --type merge --patch-file "$AM_TMP/edit.json" >/dev/null
reverted() { ! kubectl -n argocd get configmap argocd-rbac-cm -o jsonpath='{.data.policy\.csv}' | grep -q payments-oncall; }
am_wait 120 reverted || { echo "setup: Argo CD did not revert the manual edit"; exit 1; }
am_wait_app argocd-settings sync=Synced --timeout 60 || { echo "setup: argocd-settings not Synced again"; exit 1; }
am_workspace_clone argocd-settings
