# Mailroom: Argo CD access

Argo CD reads the private repo `platform/mailroom` as the Gitea machine user `argo-reader`.
It authenticates with an **access token** (scope `read:repository`), stored in the repository Secret
`repo-mailroom` in the `argocd` namespace.

Gitea machine user password (for creating tokens in Gitea, UI: Settings > Applications): `reader-pass-8Jt3`
Tokens are never reused: create a new one, give it a unique name, store it, revoke the old one.
