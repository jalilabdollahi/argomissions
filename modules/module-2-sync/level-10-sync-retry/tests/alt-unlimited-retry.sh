#!/bin/bash
# Correct too: unlimited retries (limit -1) with a capped backoff, written as YAML.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application sensor-hub --type merge \
  -p '{"spec":{"syncPolicy":{"retry":{"limit":-1,"backoff":{"duration":"10s","factor":2,"maxDuration":"1m"}}}}}'
am_argocd app sync sensor-hub --timeout 400
am_wait_app sensor-hub sync=Synced health=Healthy op=Succeeded --timeout 300
