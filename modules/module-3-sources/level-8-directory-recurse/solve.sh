#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set inventory --directory-recurse
am_argocd app sync inventory --timeout 120
am_argocd app wait inventory --health --timeout 120
