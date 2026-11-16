#!/bin/bash
# Wrong: just sync again. The Deployment already exists, is still not healthy, and the ConfigMap is still
# held back in wave 1.
set -euo pipefail
source "$AM_LIB"

# an operation is still running: the CLI refuses a second one
am_argocd app sync shipping-ui --timeout 20 || true
sleep 2
