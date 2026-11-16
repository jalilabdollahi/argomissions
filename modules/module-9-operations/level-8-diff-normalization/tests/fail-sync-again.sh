#!/bin/bash
# Wrong: pressing Sync again is not a fix: the board is applied, the next comparison is OutOfSync again.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync ops-statusboard --timeout 120
am_app_refresh ops-statusboard
sleep 8
