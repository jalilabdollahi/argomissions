#!/bin/bash
# Wrong: all five repositories made public.
set -euo pipefail
source "$AM_LIB"

for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do
  am_gitea PATCH "/repos/platform/$r" '{"private":false}' >/dev/null
  am_argocd app get "$r" --hard-refresh >/dev/null
done
for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do am_wait_app "$r" sync=Synced health=Healthy --timeout 150; done
