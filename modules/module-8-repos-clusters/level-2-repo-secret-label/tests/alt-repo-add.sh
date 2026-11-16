#!/bin/bash
# Correct too: register the repository with the CLI instead of repairing the Secret.
set -euo pipefail
source "$AM_LIB"

am_argocd repo add "$(am_repo_url parcel-tracker)" --username argo-reader --password reader-pass-4Kd9
am_argocd app get parcel-tracker --hard-refresh >/dev/null
am_wait_app parcel-tracker sync=Synced health=Healthy --timeout 150
