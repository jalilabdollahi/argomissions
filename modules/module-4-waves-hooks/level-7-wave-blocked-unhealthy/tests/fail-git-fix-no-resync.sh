#!/bin/bash
# Wrong: the probe is fixed in Git, but the stuck operation is left running (it keeps the old revision).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/fleet-tracker"
sed -i.bak 's/port: 8080/port: 5678/' deploy/api.yaml && rm -f deploy/api.yaml.bak
am_player_push . "tracker-api: readiness probe on the container port"
am_app_refresh fleet-tracker
sleep 20
