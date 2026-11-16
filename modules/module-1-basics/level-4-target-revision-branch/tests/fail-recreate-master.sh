#!/bin/bash
# Wrong: make the Application happy by pushing a master branch again.
set -euo pipefail
source "$AM_LIB"

am_repo_branch invoices master main
am_app_refresh invoices
am_argocd app sync invoices --timeout 120
am_wait_app invoices sync=Synced health=Healthy --timeout 120
