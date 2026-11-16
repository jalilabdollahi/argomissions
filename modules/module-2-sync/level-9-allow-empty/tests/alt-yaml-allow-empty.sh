#!/bin/bash
# Correct too: allowEmpty written into the Application.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application nightly-etl --type merge -p '{"spec":{"syncPolicy":{"automated":{"allowEmpty":true}}}}'
am_wait_app nightly-etl sync=Synced op=Succeeded --timeout 120
