#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set pricing-api --self-heal
am_wait_app pricing-api sync=Synced health=Healthy --timeout 120
