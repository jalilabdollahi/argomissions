#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=telemetry
am_app_exists "$APP" || am_fail "No Application named '$APP' in namespace argocd"

server="$(am_app "$APP" '{.spec.destination.server}')"
name="$(am_app "$APP" '{.spec.destination.name}')"
ns="$(am_app "$APP" '{.spec.destination.namespace}')"
if [ -n "$name" ] && [ -n "$server" ]; then am_fail "Application '$APP' sets both destination.name and destination.server"; fi
case "${server%/}${name:+name:$name}" in
  https://kubernetes.default.svc|name:in-cluster) am_ok "Application '$APP' targets the cluster Argo CD runs in" ;;
  *) am_fail "Application '$APP' targets '${server:-name $name}', which Argo CD does not know as a cluster" ;;
esac
[ "$ns" = "telemetry" ] || am_fail "Application '$APP' deploys to namespace '${ns:-<none>}', not 'telemetry'"

am_require_app_at_head "$APP" telemetry

[ "$(am_ready_replicas telemetry telemetry)" -ge 1 ] || am_fail "Deployment telemetry in namespace telemetry has no ready pod"
body="$(am_http http://telemetry.telemetry telemetry)" || am_fail "Service telemetry in namespace telemetry does not answer"
[ "$body" = "telemetry v1.7" ] || am_fail "Service telemetry answers '$body'"
am_pass "telemetry is live on the in-cluster destination"
