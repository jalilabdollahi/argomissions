#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/argocd-settings"
cat >>config/argocd-rbac-cm.yaml <<'YAML'
    # incident access: payments on-call may sync, not delete
    p, role:oncall, applications, sync, default/*, allow
    g, payments-oncall, role:oncall
YAML
am_player_push . "rbac: payments-oncall may sync applications in project default"
head="$(am_repo_head argocd-settings)"
am_app_refresh argocd-settings
am_wait_app argocd-settings sync=Synced oprev="$head" op=Succeeded --timeout 150
