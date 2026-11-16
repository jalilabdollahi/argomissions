#!/bin/bash
# Wrong (works, but not what was asked): five separate repository entries.
set -euo pipefail
source "$AM_LIB"

for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do
  am_argocd repo add "$(am_repo_url "$r")" --username argo-reader --password reader-pass-1Wm6
  am_argocd app get "$r" --hard-refresh >/dev/null
done
for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do am_wait_app "$r" sync=Synced health=Healthy --timeout 150; done
