#!/bin/bash
set -euo pipefail
source "$AM_LIB"

command -v gpg >/dev/null 2>&1 || {
  echo "setup: this mission needs gpg on the host (install GnuPG, e.g. 'brew install gnupg' or 'apt install gnupg')"
  exit 1
}

# A private keyring for the release key. Short path on purpose: gpg-agent sockets cannot live in deep directories.
export GNUPGHOME="/tmp/am-gnupg-treasury-$(id -u)"
gpgconf --kill gpg-agent >/dev/null 2>&1 || true
rm -rf "$GNUPGHOME"; mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --pinentry-mode loopback --passphrase '' \
  --quick-gen-key "ArgoMissions Player <player@argomissions.local>" ed25519 sign never >/dev/null 2>&1 \
  || { echo "setup: could not generate the release key"; exit 1; }
KEYID="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')"
gpg --armor --export "$KEYID" >"$AM_TMP/release-key.asc"

# gpg wrapper for git in the workspace (so `git commit -S` finds the release key)
cat >"$SANDBOX/gpg-release" <<WRAP
#!/bin/sh
exec gpg --homedir "$GNUPGHOME" "\$@"
WRAP
chmod +x "$SANDBOX/gpg-release"

# Argo CD trusts the release key: register it, then wait until the repo-server has loaded it
am_argocd gpg add --from "$AM_TMP/release-key.asc" >/dev/null
keyring_has_key() { kubectl -n argocd exec deploy/argocd-repo-server -c argocd-repo-server -- \
  gpg --homedir /app/config/gpg/keys --list-keys "$KEYID" >/dev/null 2>&1; }
am_wait 170 keyring_has_key || { echo "setup: the repo-server did not load the release key"; exit 1; }

# Commit 1: signed. Commit 2 (later): unsigned.
W="$AM_TMP/seed"; mkdir -p "$W"; cp -R "$LEVEL_DIR/repo/." "$W/"
am_repo_create treasury-core
git -C "$W" init -q -b main
git -C "$W" config user.name "ArgoMissions Player"; git -C "$W" config user.email "player@argomissions.local"
git -C "$W" config gpg.program "$SANDBOX/gpg-release"
git -C "$W" add -A
git -C "$W" commit -q -S -m "treasury-core v1"
git -C "$W" push -q "http://$AM_GIT_USER:$AM_GIT_PASS@localhost:$AM_GIT_PORT/$AM_ORG/treasury-core.git" HEAD:refs/heads/main

kubectl create namespace treasury >/dev/null
sed "s/__KEYID__/$KEYID/" "$LEVEL_DIR/assets/project.yaml.tpl" | kubectl apply -f - >/dev/null
kubectl -n treasury create configmap release-signing --from-literal=keyID="$KEYID" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh treasury-core
am_wait_app treasury-core sync=OutOfSync --timeout 60 || { echo "setup: treasury-core was not compared"; exit 1; }
am_argocd app sync treasury-core --timeout 120 >/dev/null
am_wait_app treasury-core sync=Synced health=Healthy --timeout 120 || { echo "setup: the signed commit did not sync"; exit 1; }

# The colleague's commit: a config change, committed without -S
sed -i.bak 's/treasury-core v1"/treasury-core v2"/; s/T+1/T+0/' "$W/deploy/configmap.yaml"; rm -f "$W/deploy/configmap.yaml.bak"
sed -i.bak 's/treasury-core v1/treasury-core v2/' "$W/deploy/deployment.yaml"; rm -f "$W/deploy/deployment.yaml.bak"
git -C "$W" add -A
git -C "$W" -c commit.gpgsign=false commit -q -m "treasury-core v2: same-day settlement window"
git -C "$W" push -q "http://$AM_GIT_USER:$AM_GIT_PASS@localhost:$AM_GIT_PORT/$AM_ORG/treasury-core.git" HEAD:refs/heads/main
am_app_refresh treasury-core
unsigned() { am_app_conditions treasury-core | grep -q 'unsigned'; }
am_wait 90 unsigned || { echo "setup: Argo CD did not report the unsigned commit"; exit 1; }

am_workspace_clone treasury-core
git -C "$SANDBOX/treasury-core" config user.name "ArgoMissions Player"
git -C "$SANDBOX/treasury-core" config user.email "player@argomissions.local"
git -C "$SANDBOX/treasury-core" config gpg.program "$SANDBOX/gpg-release"
git -C "$SANDBOX/treasury-core" config user.signingkey "$KEYID"
gpgconf --kill gpg-agent >/dev/null 2>&1 || true
