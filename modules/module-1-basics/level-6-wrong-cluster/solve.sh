#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd cluster list
am_argocd app set telemetry --dest-server https://kubernetes.default.svc
am_argocd app sync telemetry --timeout 120
am_argocd app wait telemetry --health --timeout 120
