#!/bin/bash
# Wrong: the label filter is dropped; the open PR without the label gets an environment too.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset pulse-previews --type json \
  -p '[{"op":"remove","path":"/spec/generators/0/pullRequest/gitea/labels"}]'
two_up() { [ "$(kubectl -n argocd get applications -o name | wc -l | tr -d ' ')" = 2 ]; }
am_wait 90 two_up
for a in $(kubectl -n argocd get applications -o name | sed 's#.*/##'); do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 150
done
