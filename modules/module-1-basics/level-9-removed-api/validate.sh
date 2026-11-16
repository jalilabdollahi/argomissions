#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=billing
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_require_app_at_head "$APP" billing

am_repo_checkout billing "$AM_TMP/repo" || am_fail "cannot clone the billing repo"
docs="$(am_yaml_docs_json "$AM_TMP/repo/deploy")"
n_pdb="$(echo "$docs" | jq '[.[] | select(.kind=="PodDisruptionBudget")] | length')"
[ "$n_pdb" -ge 1 ] || am_fail "The billing repo no longer ships a PodDisruptionBudget"
bad="$(echo "$docs" | jq -r '[.[] | select(.kind=="PodDisruptionBudget" and .apiVersion!="policy/v1")] | length')"
[ "$bad" = 0 ] || am_fail "A PodDisruptionBudget in the repo still uses an apiVersion the cluster does not serve"
am_ok "The repo ships a PodDisruptionBudget with a served apiVersion"

pdb_tracking="$(am_jsonpath pdb/billing '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' billing)"
[ -n "$pdb_tracking" ] || am_fail "PodDisruptionBudget billing does not exist in namespace billing as an Argo CD managed object"
am_ok "PodDisruptionBudget billing is live and managed by Argo CD"

[ "$(am_ready_replicas billing billing)" -ge 2 ] || am_fail "Deployment billing/billing has fewer than 2 ready pods"
body="$(am_http http://billing.billing billing)" || am_fail "Service billing in namespace billing does not answer"
[ "$body" = "billing v3.1" ] || am_fail "Service billing answers '$body'"
am_pass "billing v3.1 is live with its PodDisruptionBudget"
