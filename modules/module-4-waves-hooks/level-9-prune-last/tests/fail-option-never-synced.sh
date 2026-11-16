#!/bin/bash
# Wrong (incomplete): the option is set on the Application but the rename is never synced.
set -euo pipefail
source "$AM_LIB"

am_argocd app set chat-relay --sync-option CreateNamespace=true --sync-option PruneLast=true
sleep 5
