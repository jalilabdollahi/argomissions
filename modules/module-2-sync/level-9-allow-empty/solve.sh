#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set nightly-etl --sync-policy automated --auto-prune --self-heal --allow-empty
am_wait_app nightly-etl sync=Synced op=Succeeded --timeout 120
