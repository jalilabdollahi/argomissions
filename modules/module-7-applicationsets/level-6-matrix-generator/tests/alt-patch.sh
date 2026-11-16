#!/bin/bash
# Correct too: the template name changed with a JSON patch on the live ApplicationSet.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset mesh --type json \
  -p '[{"op":"replace","path":"/spec/template/metadata/name","value":"{{ .path.basename }}-{{ .env }}"}]'
for a in invoicer-staging invoicer-prod mailer-staging mailer-prod; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 150
done
