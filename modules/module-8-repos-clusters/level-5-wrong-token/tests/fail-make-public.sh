#!/bin/bash
# Wrong: the repo is made public (it does not even help: the revoked token is still presented, and
# Gitea rejects an invalid token on public repos too).
set -euo pipefail
source "$AM_LIB"

am_gitea PATCH /repos/platform/mailroom '{"private":false}' >/dev/null
am_argocd app get mailroom --hard-refresh >/dev/null
am_wait_app mailroom sync=Synced health=Healthy --timeout 25 || true
