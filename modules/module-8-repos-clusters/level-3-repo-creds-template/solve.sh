#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd repocreds add "$AM_GIT_INCLUSTER/platform" --username argo-reader --password reader-pass-1Wm6
for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do
  am_argocd app get "$r" --hard-refresh >/dev/null
done
for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do
  am_wait_app "$r" sync=Synced health=Healthy --timeout 150
done
