#!/bin/bash
# Wrong: naming the plugin in the Application. Discovery still has to match, so the plugin is never found.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application label-printer --type merge -p '{"spec":{"source":{"plugin":{"name":"kv-render"}}}}'
am_app_refresh label-printer hard
am_wait_app label-printer cond="could not find cmp-server plugin" --timeout 60
