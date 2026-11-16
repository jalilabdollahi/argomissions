#!/bin/bash
# Wrong: the template prefix names a single repository, so four apps keep failing.
set -euo pipefail
source "$AM_LIB"

am_argocd repocreds add "$(am_repo_url kiosk-menu)" --username argo-reader --password reader-pass-1Wm6
for r in kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports; do am_argocd app get "$r" --hard-refresh >/dev/null 2>&1 || true; done
sleep 5
