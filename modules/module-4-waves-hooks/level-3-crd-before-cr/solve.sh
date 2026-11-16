#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The instances need the CRD: sync the CRD Application first, then the instances.
am_argocd app sync sensor-crds --timeout 120
am_argocd app wait sensor-crds --health --timeout 120
am_argocd app sync sensor-hub --timeout 120
am_argocd app wait sensor-hub --health --timeout 120
