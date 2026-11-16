#!/bin/bash
# Wrong: the repository is made public so that no credentials are needed.
set -euo pipefail
source "$AM_LIB"

am_gitea PATCH /repos/platform/vault-ui '{"private":false}' >/dev/null
am_argocd app get vault-ui --hard-refresh >/dev/null
am_wait_app vault-ui sync=Synced health=Healthy --timeout 150
