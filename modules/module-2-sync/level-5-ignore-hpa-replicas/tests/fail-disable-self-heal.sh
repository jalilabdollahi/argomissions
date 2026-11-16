#!/bin/bash
# Wrong: self-heal switched off. The fight stops, but the Application is OutOfSync for good and drift is no longer healed.
set -euo pipefail
source "$AM_LIB"

am_argocd app set quote-api --self-heal=false
sleep 20
