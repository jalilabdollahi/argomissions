#!/bin/bash
# Wrong: delete the old Job by hand and sync. Same outcome as a plain retry.
set -euo pipefail
source "$AM_LIB"

kubectl -n helpdesk delete job helpdesk-db-migrate --ignore-not-found
am_app_sync_now helpdesk-api
am_wait_app helpdesk-api op=Succeeded sync=Synced health=Healthy --timeout 150
