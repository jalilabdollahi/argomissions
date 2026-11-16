#!/bin/bash
# Correct too: selfHeal written with kubectl patch.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application pricing-api --type merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true}}}}'
am_wait_app pricing-api sync=Synced health=Healthy --timeout 120
