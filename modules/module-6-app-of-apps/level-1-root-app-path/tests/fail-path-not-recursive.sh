#!/bin/bash
# Wrong: pointing the root at the parent folder. Directory sources do not recurse, so it is still empty.
set -euo pipefail
source "$AM_LIB"

am_argocd app set shopfront-root --path argocd
am_argocd app get shopfront-root --refresh >/dev/null
am_wait_app shopfront-root sync=Synced --timeout 120
sleep 10
