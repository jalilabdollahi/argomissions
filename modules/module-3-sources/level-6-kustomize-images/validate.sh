#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=ticket-desk
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"
src_path="$(am_app "$APP" '{.spec.source.path}')"
[ "${src_path%/}" = "kustomize/overlays/prod" ] \
  || am_fail "Application '$APP' deploys '${src_path:-<repo root>}' - it must keep deploying the production overlay"

am_require_app_at_head "$APP" ticket-desk

img="$(am_jsonpath deploy/ticket-desk '{.spec.template.spec.containers[0].image}' desk)"
[ "$img" = "traefik/whoami:v1.10" ] || am_fail "Deployment ticket-desk runs image '$img', not the build 2.0 image that staging validated"
am_ok "Deployment ticket-desk runs the build 2.0 image, as declared by the Application"

[ "$(am_ready_replicas ticket-desk desk)" -ge 2 ] || am_fail "Deployment ticket-desk has fewer than 2 ready pods"
body="$(am_http http://ticket-desk.desk desk)" || am_fail "Service ticket-desk in namespace desk does not answer"
case "$body" in *"Hostname:"*) ;; *) am_fail "Service ticket-desk does not answer like build 2.0 (got: ${body:0:60})";; esac
am_pass "ticket-desk runs the promoted image, Synced from Git and the Application"
