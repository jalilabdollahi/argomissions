# Authentication Required

## What broke
`platform/vault-ui` became private, but Argo CD was never told how to log in to it. The repo-server therefore
talked to Gitea anonymously and Git answered `authentication required: Unauthorized`. The Application itself was
fine; the failure sits in `ComparisonError` because Argo CD could not even list the refs to find `main`.

## Why Argo CD behaves this way
Argo CD stores everything it needs to reach Git *outside* the Application. Repository credentials are
**repository settings**: a Secret in the `argocd` namespace labelled `argocd.argoproj.io/secret-type: repository`
holding `url`, `type`, `username` and `password` (or an access token, an SSH key, a GitHub App). Applications only
carry a URL; when the repo-server needs that URL it looks the credentials up by URL. This keeps secrets out of
Applications, which many people can create, and lets one credential serve many apps. `argocd repo add` just
creates that Secret for you after testing the connection.

## The fix
Register the repository with the read-only machine user (`argocd repo add ... --username --password`, the UI under
Settings > Repositories, or the declarative Secret). Refresh the Application; the next fetch is authenticated.

## In real life
Almost every production repo is private, so this is the first thing every new cluster needs. Use a *machine
user* or deploy token with read-only scope per purpose, never a person's account or a site admin: the secret is
readable by anyone with `get secrets` in `argocd`, and a human's password rotates or leaves with the human.
"Just make the repo public" is not a fix, it is an incident.

## Commands worth remembering
```bash
argocd repo list
argocd repo add URL --username U --password P
argocd repo get URL
argocd app get APP --hard-refresh
kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=repository
```

## Common mistakes
- Making the repository public or reusing the admin account instead of a read-only machine user.
- Registering a URL that differs from the Application's `repoURL` (host, scheme or path): credentials match by URL.
- Forgetting to refresh and then concluding the credentials do not work; the cached error lasts until the next reconcile.
