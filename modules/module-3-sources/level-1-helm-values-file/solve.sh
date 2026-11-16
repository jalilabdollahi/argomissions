#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set weather-api --values values-production.yaml
am_argocd app sync weather-api --timeout 120
am_argocd app wait weather-api --health --timeout 120
