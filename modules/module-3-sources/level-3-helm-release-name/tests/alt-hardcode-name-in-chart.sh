#!/bin/bash
# Correct too: stop deriving the object names from the release name, in the chart itself.
set -euo pipefail
source "$AM_LIB"

am_workspace_clone fleet-tracker
cd "$SANDBOX/fleet-tracker"
sed -i.bak 's/{{ .Release.Name }}-api/tracker-api/' chart/templates/deployment.yaml chart/templates/service.yaml
rm -f chart/templates/*.bak
am_player_push . "Fixed object names in the chart"
am_app_refresh fleet-tracker
am_wait_app fleet-tracker sync=Synced health=Healthy rev="$(am_repo_head fleet-tracker)" --timeout 150
am_wait 120 kubectl -n fleet get deploy/tracker-api
kubectl -n fleet rollout status deploy/tracker-api --timeout=90s
