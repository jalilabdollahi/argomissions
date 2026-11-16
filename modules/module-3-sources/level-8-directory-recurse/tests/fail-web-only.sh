#!/bin/bash
# Wrong: point the Application at deploy/web only. The web tier appears, the database tier is still missing.
set -euo pipefail
source "$AM_LIB"

am_argocd app set inventory --path deploy/web
am_argocd app sync inventory --timeout 120
am_wait_app inventory sync=Synced health=Healthy --timeout 120
