#!/bin/bash
# Also correct: the declarative route, patch the Application with directory.recurse and sync.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application inventory --type merge -p '{"spec":{"source":{"directory":{"recurse":true}}}}'
am_wait_app inventory sync=OutOfSync --timeout 60
am_argocd app sync inventory --timeout 120
am_wait_app inventory sync=Synced health=Healthy --timeout 120
