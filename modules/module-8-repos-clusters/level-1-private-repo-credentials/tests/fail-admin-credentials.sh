#!/bin/bash
# Wrong: the human admin account is stored in Argo CD.
set -euo pipefail
source "$AM_LIB"

am_argocd repo add "$(am_repo_url vault-ui)" --username player --password "$AM_GIT_PASS"
am_argocd app get vault-ui --hard-refresh >/dev/null
am_wait_app vault-ui sync=Synced health=Healthy --timeout 150
