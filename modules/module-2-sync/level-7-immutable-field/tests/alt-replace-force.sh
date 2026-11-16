#!/bin/bash
# Correct too: both flags on the CLI.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync ticket-desk --replace --force --timeout 120
am_wait_app ticket-desk sync=Synced health=Healthy --timeout 120
