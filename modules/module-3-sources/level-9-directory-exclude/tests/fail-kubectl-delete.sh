#!/bin/bash
# Wrong: delete the junk objects by hand. Git still declares them, so the Application is OutOfSync.
set -euo pipefail
source "$AM_LIB"

kubectl -n telemetry delete deploy/fixture-loadgen pod/fixture-fake-source --wait=true
am_app_refresh collector normal
am_wait_app collector sync=OutOfSync --timeout 60
