# Unsigned Commit Rejected

## What broke
Project `treasury` lists the release key in `spec.signatureKeys`. A colleague pushed a normal, unsigned commit to
`main`. When Argo CD resolved the Application's target revision it verified the commit, found no signature and
refused to render or sync it: `GIT/GPG: Failed verifying revision ... : unsigned (key_id=)`.

## Why Argo CD behaves this way
GnuPG commit verification is a supply-chain control: only commits signed by a key you chose may reach the
cluster, even if someone gains push access. The repo-server holds a keyring built from `argocd-gpg-keys-cm`
(`argocd gpg add`), and the AppProject says which key IDs count. Verified on v3.6.1: the check applies to the commit
the Application deploys (the head of the tracked branch), so an unsigned ancestor is fine while an unsigned tip is not;
the failure is reported at comparison time, before any manifest is applied. A key that was just added needs a minute
or two before the repo-server's keyring contains it, and until then the error reads `signed with key not in keyring`.
Removing `signatureKeys` or trusting a second key makes the error go away, and also removes the control.

## The fix
Sign the tip. Either add a signed commit on top of the unsigned one or amend the unsigned tip with `-S` and
force-push (only acceptable because nobody built on it). Then sync: the signed head verifies and v2 deploys.

## In real life
Teams adopt signing after an incident, then hit this when a bot, the web UI of the Git host, or a squash-merge
creates unsigned commits (merges made by the host are signed with the host's key, which must also be trusted).
Plan key rotation (add the new key before retiring the old), keep keys in a hardware token or CI signer rather than on
laptops, and decide whether the host's merge key belongs in `signatureKeys`.

## Commands worth remembering
```bash
argocd gpg list
argocd gpg add --from key.asc
git log --show-signature -3
git log --format='%h %G? %GK %s' -5       # G good, N none, U unknown trust, B bad, E cannot check
git commit -S --amend --no-edit
```

## Common mistakes
- Deleting `signatureKeys` (or the whole project) so the app syncs: the control is gone.
- Generating a personal key and trusting it in Argo CD and the project: anyone can do that, so it proves nothing.
- Signing an older commit while the tip is still unsigned: Argo CD verifies the revision it deploys, the tip.
