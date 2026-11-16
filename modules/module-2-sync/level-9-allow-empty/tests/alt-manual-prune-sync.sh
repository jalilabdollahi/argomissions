#!/bin/bash
# Correct too: one manual sync that prunes (the allowEmpty guard only applies to automated syncs).
set -euo pipefail
source "$AM_LIB"

am_argocd app sync nightly-etl --prune --timeout 120
am_wait_app nightly-etl sync=Synced op=Succeeded --timeout 120
