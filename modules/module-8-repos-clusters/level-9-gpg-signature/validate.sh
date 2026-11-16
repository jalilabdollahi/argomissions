#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=treasury-core
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# The release key the project was set up with must still be the only accepted signer
keyid="$(kubectl -n treasury get configmap release-signing -o jsonpath='{.data.keyID}' 2>/dev/null)"
[ -n "$keyid" ] || am_fail "The release key record in namespace treasury is gone"
keys="$(kubectl -n argocd get appproject treasury -o json 2>/dev/null | jq -r '[.spec.signatureKeys[]?.keyID] | sort | join(",")')"
[ -n "$keys" ] || am_fail "Project 'treasury' no longer requires signed commits (spec.signatureKeys is empty)"
[ "$keys" = "$keyid" ] || am_fail "Project 'treasury' accepts signatures from '$keys', not only from the release key $keyid"
[ "$(am_app "$APP" '{.spec.project}')" = treasury ] || am_fail "Application '$APP' left project 'treasury'"
am_ok "Project 'treasury' still demands commits signed with the release key"

# Independent check of the head commit's signature (does not rely on Argo CD)
head="$(am_repo_head treasury-core)"
pub="$(kubectl -n argocd get configmap argocd-gpg-keys-cm -o json | jq -r --arg k "$keyid" '.data[$k] // empty')"
[ -n "$pub" ] || am_fail "Argo CD no longer has the release key in its keyring (argocd gpg list)"
vh="$(mktemp -d /tmp/am-verify.XXXXXX)"; chmod 700 "$vh"
cleanup_gpg() { GNUPGHOME="$vh" gpgconf --kill gpg-agent >/dev/null 2>&1; rm -rf "$vh"; }
trap 'cleanup_gpg; rm -rf "$AM_TMP"' EXIT
printf '%s\n' "$pub" | GNUPGHOME="$vh" gpg --batch --quiet --import >/dev/null 2>&1
am_repo_checkout treasury-core "$AM_TMP/check" || am_fail "Cannot read the treasury-core repo"
sig="$(GNUPGHOME="$vh" git -C "$AM_TMP/check" log -1 --format='%G?:%GK' 2>/dev/null)"
case "$sig" in
  [GU]:*"$keyid") ;;
  N:*) am_fail "The head commit of treasury-core (${head:0:7}) is not signed" ;;
  *) am_fail "The head commit of treasury-core (${head:0:7}) has no valid signature from the release key (git reports '$sig')" ;;
esac
am_ok "Head commit ${head:0:7} carries a valid signature from the release key"

am_require_app_at_head "$APP" treasury-core
am_require_synced_by_argo "$APP" treasury-core
[ "$(am_jsonpath configmap/treasury-config '{.data.settlement-window}' treasury)" = "T+0" ] \
  || am_fail "ConfigMap treasury-config does not carry the same-day settlement window from the latest change"
body="$(am_http http://treasury-core.treasury treasury)" || am_fail "Service treasury-core does not answer"
[ "$body" = "treasury-core v2" ] || am_fail "Service treasury-core answers '$body'"
am_pass "treasury-core v2 is live from a signed commit"
