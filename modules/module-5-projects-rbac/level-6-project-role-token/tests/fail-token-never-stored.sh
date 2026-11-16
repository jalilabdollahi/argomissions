#!/bin/bash
# Wrong: role, policies and token exist, but the token was only printed in a terminal - the pipeline's Secret is untouched.
set -euo pipefail
source "$AM_LIB"

am_argocd proj role create settlements deployer
am_argocd proj role add-policy settlements deployer --action get  --permission allow --object '*'
am_argocd proj role add-policy settlements deployer --action sync --permission allow --object '*'
am_argocd proj role create-token settlements deployer --token-only >/dev/null
