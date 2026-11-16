#!/bin/bash
# Correct too: the same result written into the AppProject manifest (manualSync: true) instead of the CLI shortcut.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject billing-core --type json \
  -p '[{"op":"add","path":"/spec/syncWindows/0/manualSync","value":true}]' >/dev/null
am_argocd app sync statement-api --timeout 120
am_wait_app statement-api sync=Synced health=Healthy --timeout 120
