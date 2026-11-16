#!/bin/bash
# Wrong: one manual sync undoes today's drift, but nothing stops the next one.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync pricing-api --timeout 120
am_wait_app pricing-api sync=Synced health=Healthy --timeout 120
