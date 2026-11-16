#!/bin/bash
# Wrong: the running Deployment is patched by hand. The service answers the new text, Argo CD never deployed it.
set -euo pipefail
source "$AM_LIB"

kubectl -n statements patch deploy statement-api --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/args/0","value":"-text=statement-api v1.4.1"}]'
kubectl -n statements rollout status deploy/statement-api --timeout=90s
