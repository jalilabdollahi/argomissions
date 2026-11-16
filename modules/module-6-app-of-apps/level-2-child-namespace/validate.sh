#!/bin/bash
set -uo pipefail
source "$AM_LIB"

ROOT=billing-root
am_require_app_at_head "$ROOT" billing-gitops

# The root must own the children in namespace argocd, and nothing in any other namespace.
am_app_json "$ROOT" | jq -r '.status.resources[]? | select(.kind=="Application") | "\(.namespace)/\(.name)"' | sort >"$AM_TMP/owned.txt"
for child in invoice-api dunning-worker; do
  grep -qx "argocd/$child" "$AM_TMP/owned.txt" \
    || am_fail "Application '$child' is not among the objects '$ROOT' maintains in namespace argocd"
done
stray="$(kubectl get applications.argoproj.io -A --no-headers 2>/dev/null | awk '$1!="argocd"{print $1"/"$2}')"
[ -z "$stray" ] || am_fail "Application objects exist outside namespace argocd, where nothing reconciles them: $(echo $stray | tr '\n' ' ')"
am_ok "invoice-api and dunning-worker are maintained by $ROOT in namespace argocd, none left elsewhere"

for pair in invoice-api:billing-invoice:"invoice-api v3.2" dunning-worker:billing-dunning:"dunning-worker v1.8"; do
  IFS=: read -r child ns want <<<"$pair"
  am_require_app_at_head "$child" billing-gitops
  body="$(am_http "http://$child.$ns" "$ns")" || am_fail "Service $child in namespace $ns does not answer"
  [ "$body" = "$want" ] || am_fail "Service $child answers '$body'"
done
am_pass "billing-root generates invoice-api and dunning-worker where Argo CD can see them, both live"
