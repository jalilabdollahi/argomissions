#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd proj add-source claims "$(am_repo_url intake-gateway)"
am_app_refresh claims-intake
am_wait_app claims-intake sync=Synced health=Healthy --timeout 150
