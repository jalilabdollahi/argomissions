#!/bin/bash
# Wrong: the name uses the environment only, so the two services still collide.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset mesh --type json \
  -p '[{"op":"replace","path":"/spec/template/metadata/name","value":"{{.env}}"}]'
sleep 20
