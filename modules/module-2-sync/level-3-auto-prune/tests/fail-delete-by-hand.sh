#!/bin/bash
# Wrong: the orphan is deleted by hand, the policy still does not prune.
set -euo pipefail
source "$AM_LIB"

kubectl -n gallery delete svc gallery-classic
am_wait_app gallery-web sync=Synced health=Healthy --timeout 120
