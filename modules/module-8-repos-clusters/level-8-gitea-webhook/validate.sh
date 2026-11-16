#!/bin/bash
set -uo pipefail
source "$AM_LIB"

HOOKS="/repos/platform/catalog-api/hooks"
verified="$(kubectl -n argocd get secret argocd-secret -o json | jq -r '.data["webhook.gogs.secret"] // "" | @base64d')"
[ -n "$verified" ] || am_fail "Argo CD verifies no signature on push events from Gitea: no secret is configured for the handler that receives them"

# Hooks of the repo that call Argo CD
ids="$(am_gitea GET "$HOOKS" | jq -r '.[] | select(.config.url | test("argocd-server.*/api/webhook")) | .id')"
[ -n "$ids" ] || am_fail "Repo catalog-api has no webhook that calls Argo CD's /api/webhook"
for id in $ids; do
  h="$(am_gitea GET "$HOOKS/$id")"
  [ "$(jq -r .active <<<"$h")" = true ] || am_fail "The Gitea webhook $id of catalog-api is not active"
  jq -e '.events | index("push")' <<<"$h" >/dev/null || am_fail "The Gitea webhook $id of catalog-api does not send push events"
  [ "$(jq -r '.config.content_type' <<<"$h")" = json ] || am_fail "The Gitea webhook $id of catalog-api does not send application/json"
done
am_ok "Catalog-api has an active push webhook to Argo CD"

# Ask Gitea to deliver for each hook, and read what Argo CD says about it
for id in $ids; do
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  am_gitea POST "$HOOKS/$id/tests" >/dev/null 2>&1 || am_fail "Gitea cannot send a test delivery for webhook $id"
  outcome() { kubectl -n argocd logs deploy/argocd-server --since-time="$since" 2>/dev/null \
      | grep -E 'Received push event|HMAC verification failed' | head -1; }
  res=""; for _ in $(seq 1 10); do res="$(outcome)"; [ -n "$res" ] && break; sleep 2; done
  case "$res" in
    *"Received push event"*) ;;
    *HMAC*) am_fail "Argo CD refuses Gitea's delivery of webhook $id (HMAC verification failed, HTTP 400)" ;;
    *) am_fail "Argo CD received nothing from Gitea's webhook $id" ;;
  esac
done
am_ok "Argo CD accepts the deliveries of Gitea's webhook"

# Still authenticated: a forged delivery is refused
head="$(am_repo_head catalog-api)"
body="{\"ref\":\"refs/heads/main\",\"before\":\"0000000000000000000000000000000000000000\",\"after\":\"$head\",\"commits\":[],\"repository\":{\"html_url\":\"$AM_GIT_INCLUSTER/platform/catalog-api\",\"clone_url\":\"$AM_GIT_INCLUSTER/platform/catalog-api.git\",\"default_branch\":\"main\"}}"
sig="$(printf %s "$body" | openssl dgst -sha256 -hmac "not-the-secret-$RANDOM" | awk '{print $NF}')"
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST -H 'Content-Type: application/json' \
  -H 'X-Gogs-Event: push' -H "X-Gogs-Signature: $sig" -d "$body" "http://$AM_ARGOCD_ADDR/api/webhook")"
[ "$code" = 400 ] || am_fail "Argo CD also accepts push events with a wrong signature: the webhook is not authenticated"
am_ok "Argo CD refuses a push event signed with another secret"

synced_at_head() { [ "$(am_app_sync catalog-api)" = Synced ] && [ "$(am_app_rev catalog-api)" = "$(am_repo_head catalog-api)" ]; }
am_app_refresh catalog-api hard
am_wait 150 synced_at_head
am_require_app_at_head catalog-api catalog-api
am_pass "Gitea's push events are verified by Argo CD"
