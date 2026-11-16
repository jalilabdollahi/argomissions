#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd repo add "$(am_repo_url vault-ui)" --username argo-reader --password reader-pass-7Q2x
am_argocd app get vault-ui --hard-refresh >/dev/null
am_wait_app vault-ui sync=Synced health=Healthy --timeout 150
