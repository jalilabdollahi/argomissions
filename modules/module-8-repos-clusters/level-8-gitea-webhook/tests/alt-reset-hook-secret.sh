#!/bin/bash
# Correct too: keep Argo CD's (Gogs) secret and re-create the Gitea hook with that same secret
# (on Gitea 28.4 a PATCH of config.secret through the API is ignored, so the hook is deleted and created again).
set -euo pipefail
source "$AM_LIB"

secret="$(kubectl -n argocd get secret argocd-secret -o json | jq -r '.data["webhook.gogs.secret"] | @base64d')"
for id in $(am_gitea GET /repos/platform/catalog-api/hooks | jq -r '.[].id'); do
  am_gitea DELETE "/repos/platform/catalog-api/hooks/$id" >/dev/null
done
am_gitea POST /repos/platform/catalog-api/hooks "$(jq -nc --arg s "$secret" \
  '{type:"gitea",active:true,events:["push"],config:{url:"http://argocd-server.argocd.svc.cluster.local/api/webhook",content_type:"json",secret:$s}}')" >/dev/null
