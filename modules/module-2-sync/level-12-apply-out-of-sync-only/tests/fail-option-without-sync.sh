#!/bin/bash
# Wrong: the option is set but r42 is never synced.
set -euo pipefail
source "$AM_LIB"

am_argocd app set region-configs --sync-option ApplyOutOfSyncOnly=true
