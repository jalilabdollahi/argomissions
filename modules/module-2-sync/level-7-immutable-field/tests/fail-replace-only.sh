#!/bin/bash
# Wrong: Replace=true alone. kubectl replace cannot change a selector either.
set -euo pipefail
source "$AM_LIB"

am_argocd app set ticket-desk --sync-option Replace=true
am_argocd app sync ticket-desk --timeout 60 >/dev/null 2>&1 || true
