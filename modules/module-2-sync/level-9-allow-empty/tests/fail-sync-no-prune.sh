#!/bin/bash
# Wrong: a manual sync without prune. Nothing is removed and the app keeps wanting to prune.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync nightly-etl --timeout 60 >/dev/null 2>&1 || true
