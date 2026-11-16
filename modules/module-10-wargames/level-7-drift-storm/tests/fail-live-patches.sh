#!/bin/bash
# Wrong: everything is done on the live objects (unpin, ignore rule, self-heal); Git is never touched, the duplicate
# ConfigMap stays, and the root's self-heal erases the rules again.
set -euo pipefail
source "$AM_LIB"
am_argocd app set stormwatch-root --sync-policy automated --self-heal
am_argocd app set sw-alerts --revision main
am_argocd app patch sw-ingest --type merge --patch '{"spec":{"ignoreDifferences":[{"group":"apps","kind":"Deployment","jqPathExpressions":[".metadata.annotations[\"mesh.argomissions.io/epoch\"]"]}]}}'
sleep 30
for a in stormwatch-root sw-ingest sw-alerts; do am_app_refresh "$a"; done
sleep 10
