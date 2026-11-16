#!/bin/bash
# Wrong: the collision is avoided by deploying only staging; prod is lost.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset mesh --type json \
  -p '[{"op":"remove","path":"/spec/generators/0/matrix/generators/1/list/elements/1"}]'
am_wait_app invoicer sync=Synced health=Healthy --timeout 150
am_wait_app mailer sync=Synced health=Healthy --timeout 150
