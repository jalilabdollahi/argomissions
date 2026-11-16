#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=argocd-settings
am_require_app_at_head "$APP" argocd-settings
am_require_synced_by_argo "$APP" argocd-settings
[ "$(am_app "$APP" '{.spec.syncPolicy.automated.selfHeal}')" = true ] \
  || am_fail "Application '$APP' no longer self-heals: the cluster is not protected against manual edits any more"

can() { am_argocd admin settings rbac can "$@" --namespace argocd 2>/dev/null | tail -1; }
[ "$(can payments-oncall sync applications 'default/anything')" = Yes ] \
  || am_fail "Members of payments-oncall are still denied 'sync' on applications in project default"
[ "$(can payments-oncall delete applications 'default/anything')" = No ] \
  || am_fail "Members of payments-oncall may delete applications: more than the on-call needs"
[ "$(can payments-oncall override applications 'default/anything')" = No ] \
  || am_fail "Members of payments-oncall may override applications: more than the on-call needs"
[ "$(can payments-oncall sync applications 'other-project/anything')" = No ] \
  || am_fail "Members of payments-oncall may sync applications outside project default"
am_ok "payments-oncall may sync in project default, and nothing more"
[ "$(can platform-auditors get logs 'default/anything')" = Yes ] \
  || am_fail "The platform auditors lost their access to logs"
am_ok "The auditors' read-only access is intact"

# The permission is in Git, not only in the cluster.
work="$AM_TMP/repo"
am_repo_checkout argocd-settings "$work" || am_fail "Cannot clone argocd-settings"
grep -q payments-oncall "$work/config/argocd-rbac-cm.yaml" || am_fail "Git (config/argocd-rbac-cm.yaml) does not mention payments-oncall"
am_ok "The permission is committed to Git"

# The game cluster's own settings must survive being managed from Git.
[ "$(am_jsonpath configmap/argocd-cm '{.data.timeout\.reconciliation}' argocd)" = 60s ] || am_fail "argocd-cm: timeout.reconciliation is not 60s any more"
[ "$(am_jsonpath configmap/argocd-cm '{.data.admin\.enabled}' argocd)" = true ] || am_fail "argocd-cm: admin.enabled is not true any more"
[ "$(am_jsonpath configmap/argocd-cm '{.data.url}' argocd)" = "http://localhost:$AM_ARGOCD_PORT" ] || am_fail "argocd-cm: url changed"
am_pass "Argo CD's configuration is changed the GitOps way"
