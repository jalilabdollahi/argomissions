#!/bin/bash
# Correct too: the orphan is deleted by hand; Git already says it must not exist, so the app turns Synced.
set -euo pipefail
source "$AM_LIB"

kubectl -n media-prod delete deploy legacy-worker --wait=true
am_app_refresh media
am_wait_app media sync=Synced health=Healthy --timeout 90
