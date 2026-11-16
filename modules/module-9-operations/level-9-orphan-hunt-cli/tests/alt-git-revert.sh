#!/bin/bash
# Correct too: git revert of the culprit commit (it touches different lines than the later releases).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/rates-service"
culprit="$(git log --format='%H %s' | awk '/Align environment values/{print $1}')"
git revert --no-edit "$culprit" >/dev/null
git push -q origin HEAD
am_app_refresh rates-service
head="$(am_repo_head rates-service)"
am_wait_app rates-service sync=Synced health=Healthy op=Succeeded oprev="$head" --timeout 150
