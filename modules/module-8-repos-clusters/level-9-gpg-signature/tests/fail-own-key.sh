#!/bin/bash
# Wrong: mint a new key, trust it in Argo CD and the project, and sign with that instead.
set -euo pipefail
source "$AM_LIB"

export GNUPGHOME="/tmp/am-gnupg-own-$(id -u)"
gpgconf --kill gpg-agent >/dev/null 2>&1 || true
rm -rf "$GNUPGHOME"; mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --pinentry-mode loopback --passphrase '' --quick-gen-key "Shortcut <shortcut@argomissions.local>" ed25519 sign never >/dev/null 2>&1
own="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')"
gpg --armor --export "$own" >"$AM_TMP/own.asc"
am_argocd gpg add --from "$AM_TMP/own.asc" >/dev/null
old="$(kubectl -n argocd get appproject treasury -o jsonpath='{.spec.signatureKeys[0].keyID}')"
kubectl -n argocd patch appproject treasury --type merge \
  -p "{\"spec\":{\"signatureKeys\":[{\"keyID\":\"$old\"},{\"keyID\":\"$own\"}]}}" >/dev/null
cd "$SANDBOX/treasury-core"
git -c user.signingkey="$own" -c gpg.program="gpg" commit -q -S --allow-empty -m "Sign with my own key"
git push -q origin HEAD
gpgconf --kill gpg-agent >/dev/null 2>&1 || true
rm -rf "$GNUPGHOME"
sleep 5
