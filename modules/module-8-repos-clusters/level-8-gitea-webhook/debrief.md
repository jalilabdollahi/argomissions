# Waiting For The Poll

## What broke
Gitea's push webhook reached Argo CD's `/api/webhook` endpoint but was refused with `HTTP 400 Webhook processing
failed` (`HMAC verification failed` in the server log, red entries in Gitea's Recent Deliveries). The hook's secret was in
`argocd-secret` under `webhook.gitea.secret`, a key Argo CD never reads, while the key it does read held an old value from a previous
Git server. So every push was noticed only by the 60-second poll.

## Why Argo CD behaves this way
`/api/webhook` is one URL for every provider. Argo CD identifies the provider from the request headers and uses that
provider's handler and secret: `webhook.github.secret`, `webhook.gitlab.secret`, `webhook.bitbucket.uuid`,
`webhook.bitbucketserver.secret`, `webhook.gogs.secret`, `webhook.azuredevops.*`. Verified on v3.6.1: a
delivery with Gitea's header set (`X-Gitea-Event`, `X-Gogs-Event`, `X-GitHub-Event`, each with a signature) is verified
with `webhook.gogs.secret`; a delivery signed with `webhook.github.secret` is refused, and there is no
`webhook.gitea.secret`. If the matching key is empty Argo CD accepts the event without checking anything. A verified
push event for a repo URL and revision that an Application uses makes Argo CD refresh that Application at once
instead of waiting for `timeout.reconciliation`.
The repository URL in the event must match the Application's `repoURL`. Observed in this lab: Gitea announces
repositories under its public `ROOT_URL` (`http://localhost:<port>/...`) while Argo CD reads them from the in-cluster
address, so an accepted delivery is logged (`Received push event`) but refreshes nothing here. In real installations both
sides use the same URL, and the refresh follows at once.

## The fix
Make the key Argo CD reads, `webhook.gogs.secret`, equal to the hook's secret (or re-create the hook in Gitea with
the value Argo CD holds; Gitea never shows a stored secret again). Argo CD reloads `argocd-secret` on its own.

## In real life
Webhooks fail silently: the provider shows a red delivery, nobody looks, and the team lives with the poll interval.
Check Recent Deliveries in the Git provider after creating a hook, keep the secret in one place, and remember that a
cluster without a webhook secret accepts forged events (they can only cause refreshes, but still).
Gitea 28 also refuses webhook targets on private addresses unless `ALLOWED_HOST_LIST` allows them. Large installations lengthen the poll interval to cut load and rely entirely on webhooks.

## Commands worth remembering
```bash
kubectl -n argocd logs deploy/argocd-server | grep -i webhook
kubectl -n argocd get secret argocd-secret -o json | jq -r '.data | keys[]' | grep webhook
argocd app get APP --refresh        # what a webhook triggers, by hand
```

## Common mistakes
- Looking for `webhook.gitea.secret`: it does not exist. Gitea hooks use the Gogs key.
- Clearing the secret so deliveries succeed: Argo CD then accepts unsigned events from anyone.
- Changing only the Git provider's hook and never checking the Argo CD side (or the other way round).
