#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd proj windows enable-manual-sync billing-core 0
am_argocd app sync statement-api --timeout 120
am_wait_app statement-api sync=Synced health=Healthy --timeout 120
