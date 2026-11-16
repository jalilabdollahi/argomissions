#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set invoices --revision main
am_argocd app sync invoices --timeout 120
am_argocd app wait invoices --health --timeout 120
