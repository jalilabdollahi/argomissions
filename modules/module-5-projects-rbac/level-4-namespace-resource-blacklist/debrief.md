# Secrets Are Blocked

## What broke
The sync was refused with `resource :Secret is not permitted in project mailroom`. The repository contained a
Secret manifest and the `mailroom` project has `Secret` in its `namespaceResourceBlacklist`. Argo CD validates
the whole sync first, so the Deployment and Service were not created either.

## Why Argo CD behaves this way
For namespaced resources an AppProject allows everything except what its blacklist names (a
`namespaceResourceWhitelist` flips that to allow-only). Here the platform team used the blacklist as a guard rail:
plain Secrets in Git are base64, not encryption, and anyone with read access to the repo (or its history) can
read them. The rule is the policy, the failing sync is the policy working. The question to ask is therefore not
"how do I get past it" but "how should this Secret reach the cluster?".

## The fix
Take the Secret manifest out of Git and provide `relay-credentials` out of band: created by the platform team,
synced from a vault by an operator (External Secrets, CSI driver), or sealed. The Deployment keeps referencing it
by name, Argo CD never touches it, and the sync succeeds. A ConfigMap in Git with the same token would only hide
the problem; and because the token was committed it must be rotated.

## In real life
Teams add the `Secret` blacklist (or deny it with admission policy) exactly to force a secrets-management story.
The honest options are: sealed-secrets or SOPS (encrypted in Git, decrypted in cluster), external-secrets
(reference only), or a manually provisioned Secret. Removing the blacklist is a policy change that belongs to
whoever owns the policy.

## Commands worth remembering
```bash
argocd proj get mailroom
argocd proj deny-namespace-resource mailroom "" Secret
argocd proj allow-namespace-resource mailroom "" Secret
kubectl -n mailroom create secret generic NAME --from-literal=KEY=VALUE
git rm deploy/secret.yaml
```

## Common mistakes
- Deleting the blacklist entry: the sync works and the security rule is gone for the whole team.
- Creating the Secret by hand but leaving the manifest in Git: the sync is still refused.
- Moving the token to a ConfigMap, or committing it anywhere else: the credential is still in Git.
