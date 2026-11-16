#!/bin/bash
# Wrong: a manual refresh gets the release out, but the 24h timeout is still live.
set -euo pipefail
source "$AM_LIB"

am_app_refresh lobby-board
head="$(am_repo_head lobby-board)"
am_wait_app lobby-board sync=Synced health=Healthy op=Succeeded oprev="$head" --timeout 150
