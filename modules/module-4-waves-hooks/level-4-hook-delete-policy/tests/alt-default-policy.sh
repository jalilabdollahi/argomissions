#!/bin/bash
# Correct too: no hook-delete-policy at all (Argo CD's default is BeforeHookCreation).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/helpdesk-api"
sed -i.bak '/hook-delete-policy/d' deploy/migrate-job.yaml && rm -f deploy/migrate-job.yaml.bak
am_player_push . "migration hook: default delete policy"
am_app_refresh helpdesk-api
am_wait_app helpdesk-api sync=OutOfSync rev="$(am_repo_head helpdesk-api)" --timeout 90
am_argocd app sync helpdesk-api --timeout 150
am_wait_app helpdesk-api sync=Synced health=Healthy op=Succeeded --timeout 120
