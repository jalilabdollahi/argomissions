#!/bin/bash
# Correct too: start the sync through the API, like the UI button.
set -euo pipefail
source "$AM_LIB"

am_app_sync_now search-api
am_wait_app search-api op=Succeeded sync=Synced health=Healthy --timeout 120
