#!/bin/bash
# Wrong: the Application is pointed at the hotfix branch by hand; the ApplicationSet takes it back.
set -euo pipefail
source "$AM_LIB"

am_argocd app set feedhub-prod --revision hotfix-1.8.1
sleep 10
