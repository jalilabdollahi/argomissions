#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=reports
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_repo_checkout reports "$AM_TMP/repo" || am_fail "cannot clone the reports repo"
cd "$AM_TMP/repo" || am_fail "cannot enter the clone"
bad="$(git log --format=%H --grep='^tune worker flags' main | head -1)"
[ -n "$bad" ] || am_fail "The commit 'tune worker flags' is no longer in the history of main (history was rewritten)"
head="$(git rev-parse HEAD)"
[ "$head" != "$bad" ] || am_fail "main still ends with the commit 'tune worker flags'; nothing undid it"
git merge-base --is-ancestor "$bad" "$head" || am_fail "The commit 'tune worker flags' is not an ancestor of main"
am_ok "History is intact: 'tune worker flags' is still an ancestor of main"

git show "$bad^:deploy/deployment.yaml" >"$AM_TMP/before.yaml" 2>/dev/null || am_fail "cannot read the manifest from before the commit"
a_before="$(am_yaml_get "$AM_TMP/before.yaml" spec.template.spec.containers.0.args | jq -c .)"
a_head="$(am_yaml_get "$AM_TMP/repo/deploy/deployment.yaml" spec.template.spec.containers.0.args | jq -c .)"
[ "$a_before" = "$a_head" ] || am_fail "The worker arguments on main are not what they were before 'tune worker flags'"
am_ok "The change of 'tune worker flags' is undone on main"

am_require_app_at_head "$APP" reports

[ "$(am_ready_replicas report-worker reports)" -ge 1 ] || am_fail "Deployment reports/report-worker has no ready pod"
live="$(am_jsonpath deploy/report-worker '{.spec.template.spec.containers[0].args}' reports)"
[ "$(echo "$live" | jq -c .)" = "$a_before" ] || am_fail "The live worker runs with arguments $live"
body="$(am_http http://report-worker.reports reports)" || am_fail "Service report-worker in namespace reports does not answer"
[ "$body" = "reports v1.0" ] || am_fail "Service report-worker answers '$body'"
am_pass "report-worker behaves as before and Git history is intact"
