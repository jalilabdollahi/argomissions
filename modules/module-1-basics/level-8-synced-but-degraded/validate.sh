#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=notifier
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_repo_checkout notifier "$AM_TMP/repo" || am_fail "cannot clone the notifier repo"
docs="$(am_yaml_docs_json "$AM_TMP/repo/deploy")"
image="$(echo "$docs" | jq -r '[.[] | select(.kind=="Deployment" and .metadata.name=="notifier")][0].spec.template.spec.containers[0].image // ""')"
[ "$image" = "hashicorp/http-echo:1.0" ] \
  || am_fail "The Deployment in Git still references image '${image:-<none>}', which cannot be pulled"
am_ok "Git references an image that exists"

am_require_app_at_head "$APP" notifier

[ "$(am_ready_replicas notifier messaging)" -ge 1 ] || am_fail "Deployment messaging/notifier has no ready pod"
live="$(am_jsonpath deploy/notifier '{.spec.template.spec.containers[0].image}' messaging)"
[ "$live" = "$image" ] || am_fail "The live Deployment runs image '$live', Git says '$image'"
am_ok "Deployment notifier is available"

body="$(am_http http://notifier.messaging messaging)" || am_fail "Service notifier in namespace messaging does not answer"
[ "$body" = "notifier v2.0" ] || am_fail "Service notifier answers '$body'"
am_pass "notifier v2.0 is live and healthy"
