#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# --force: delete and re-create objects that cannot be updated in place
am_argocd app sync ticket-desk --force --timeout 120
am_wait_app ticket-desk sync=Synced health=Healthy --timeout 120
