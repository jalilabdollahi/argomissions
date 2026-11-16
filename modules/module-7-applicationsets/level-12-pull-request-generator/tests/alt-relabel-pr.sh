#!/bin/bash
# Correct too: the generator is left alone; the open PR also gets the label the ApplicationSet filters on.
set -euo pipefail
source "$AM_LIB"

lab="$(am_gitea POST /repos/platform/pulse-web/labels '{"name":"preview","color":"#0e8a16"}' | jq -r .id)"
n="$(am_gitea GET "/repos/platform/pulse-web/pulls?state=open" | jq -r '[.[] | select(.head.ref=="checkout-redesign")][0].number')"
am_gitea POST "/repos/platform/pulse-web/issues/$n/labels" "{\"labels\":[$lab]}" >/dev/null
app_up() { [ "$(kubectl -n argocd get applications -o name | wc -l | tr -d ' ')" = 1 ]; }
am_wait 120 app_up
am_wait_app "pulse-pr-$n" sync=Synced health=Healthy --timeout 150
