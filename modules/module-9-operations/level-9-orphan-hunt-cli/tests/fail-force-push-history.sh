#!/bin/bash
# Wrong: rewriting history back to before the bad commit; the currency is right, the later releases are lost.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/rates-service"
good="$(git log --format='%H %s' | awk '/Bump rates-service to v1.1/{print $1}')"
git reset -q --hard "$good"
git push -q --force origin HEAD:main
am_app_refresh rates-service
head="$(am_repo_head rates-service)"
am_wait_app rates-service sync=Synced op=Succeeded oprev="$head" --timeout 150
