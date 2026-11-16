#!/bin/bash
# Wrong: sync again and hope. The test still calls the wrong port.
set -euo pipefail
source "$AM_LIB"

am_app_sync_now booking-web
am_wait_app booking-web op=Failed --timeout 120
for j in $(kubectl -n booking get jobs -o name); do kubectl -n booking patch "$j" --type merge -p '{"metadata":{"finalizers":null}}' >/dev/null; done
