#!/bin/bash
# Wrong: delete the leftovers with kubectl. The app goes Synced, but no sync ever ran at the new commit.
set -euo pipefail
source "$AM_LIB"

kubectl -n etl delete deploy etl-worker
kubectl -n etl delete svc etl-status
kubectl -n etl delete cm etl-schedule
am_wait_app nightly-etl sync=Synced --timeout 90
