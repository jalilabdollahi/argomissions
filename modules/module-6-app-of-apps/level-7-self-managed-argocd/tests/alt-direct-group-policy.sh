#!/bin/bash
# Correct too: the group is granted `sync` directly, without a role; edited in Git, applied by Argo CD.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/argocd-settings"
cat >>config/argocd-rbac-cm.yaml <<'YAML'
    p, payments-oncall, applications, sync, default/*, allow
YAML
am_player_push . "rbac: payments-oncall may sync in default"
head="$(am_repo_head argocd-settings)"
am_app_refresh argocd-settings
am_wait_app argocd-settings sync=Synced oprev="$head" op=Succeeded --timeout 150
