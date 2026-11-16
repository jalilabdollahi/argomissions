#!/bin/bash
# Wrong: "just sync again". The failed hook was cleaned up (HookFailed), so the second try goes through, but Git
# still leaves every successful run behind: the next change to the Job fails again.
set -euo pipefail
source "$AM_LIB"

am_app_sync_now helpdesk-api
am_wait_app helpdesk-api op=Succeeded sync=Synced health=Healthy --timeout 150
