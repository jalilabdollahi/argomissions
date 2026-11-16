#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set catalog --path deploy/catalog
am_argocd app sync catalog --timeout 120
am_argocd app wait catalog --health --timeout 120
