# Expired Credentials

## What broke
The access token stored in the repository Secret was revoked in Gitea. The Secret looked fine (right label, right URL,
a long password-like value) and the app kept showing the last good revision, but every new fetch from Git was refused with
`authentication required`, so v3.2 was never seen. Nothing in the cluster had changed, which is what makes this failure
confusing: the credentials rotted in Gitea.

## Why Argo CD behaves this way
Argo CD does not validate a token when you store it later; it just presents the stored username/password to Git on every
`ls-remote`/fetch. When Git says 401, the repo-server reports it and the Application gets a `ComparisonError`.
The Application keeps showing its *last successfully compared* revision, and live objects keep running: an expired token
stops *new* deployments, not the running ones, so the outage is silent until someone pushes. `argocd repo list` runs a live
connection test per repository and is the quickest place to see `Failed`.

## The fix
Mint a new token for the machine user, store it in the repository Secret (`argocd repo add ... --upsert`, a patch, or
your secret manager), and hard-refresh. Then revoke old tokens; never leave two live for no reason.

## In real life
Tokens have expiry dates, owners leave, security scans rotate secrets. Give machine tokens a calendar owner and a
rotation runbook, scope them to `read:repository` only, and prefer tooling that makes rotation a one-line change
(External Secrets, sealed secrets, a GitHub App that mints short-lived tokens). Alert on the `ComparisonError` condition or
on `argocd_app_info` showing `sync_status="Unknown"`: a Git credential failure should page before the next release does.

## Commands worth remembering
```bash
argocd repo list
argocd repo add URL --username U --password TOKEN --upsert
kubectl -n argocd patch secret NAME --type merge -p '{"stringData":{"password":"..."}}'
argocd app get APP --hard-refresh
```

## Common mistakes
- Replacing the token with the admin account's password because it "just works".
- Creating a new token in Gitea and forgetting to store it in Argo CD.
- Making the repository public to stop the errors.
