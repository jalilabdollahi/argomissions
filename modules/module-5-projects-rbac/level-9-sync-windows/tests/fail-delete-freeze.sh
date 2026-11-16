#!/bin/bash
# Wrong: the freeze is deleted. The fix goes out (even automatically), and so would everything else.
set -euo pipefail
source "$AM_LIB"

am_argocd proj windows delete billing-core 0
am_argocd app sync statement-api --timeout 120
am_wait_app statement-api sync=Synced health=Healthy --timeout 120
