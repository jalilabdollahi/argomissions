#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/helpdesk-api"
sed -i.bak 's/hook-delete-policy: HookFailed/hook-delete-policy: BeforeHookCreation/' deploy/migrate-job.yaml && rm -f deploy/migrate-job.yaml.bak
am_player_push . "migration hook: delete the previous run before creating a new one"
am_app_refresh helpdesk-api
am_wait_app helpdesk-api sync=OutOfSync rev="$(am_repo_head helpdesk-api)" --timeout 90
am_argocd app sync helpdesk-api --timeout 150
am_argocd app wait helpdesk-api --health --timeout 120
