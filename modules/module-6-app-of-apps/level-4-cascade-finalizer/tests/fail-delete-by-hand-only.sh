#!/bin/bash
# Partial: the orphan is deleted with kubectl, but nothing changes in Git: the next retirement leaks again.
set -euo pipefail
source "$AM_LIB"

kubectl delete namespace tariff-old --wait=true
