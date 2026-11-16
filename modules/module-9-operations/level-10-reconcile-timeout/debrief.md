# Why So Slow?

## What broke
A well-meant CPU saving, `timeout.reconciliation: 24h`, turned Argo CD from "looks at Git every few minutes"
into "looks at Git once a day". Pushes were not noticed, the Application kept reporting Synced (it was, with
respect to the last commit it had looked at) and nothing alerted anyone. A manual refresh hid the problem by
making the app catch up on demand.

## Why Argo CD behaves this way
Argo CD polls. The application controller compares every Application with Git each `timeout.reconciliation`
(180s by default, plus `timeout.reconciliation.jitter` to spread the load), and the repo-server caches the
answer to "what commit is this branch at" for the same duration, so a shorter controller tick alone would still
be served the old commit. In this installation `argocd-cm` is wired into both pods as the environment variable
`ARGOCD_RECONCILIATION_TIMEOUT`; environment variables are read when a process starts, which is why editing the
ConfigMap changes nothing until the pods restart. (Settings in `argocd-cm` such as `resource.customizations` or
`url` are watched live, but `timeout.*` and everything in `argocd-cmd-params-cm` are start-up parameters.)
After the restart one manual refresh makes the app catch up immediately instead of waiting for the next tick.

## The fix
Restore a sane value, restart the application controller and the repo-server, refresh once. Do not stop at the
ConfigMap, and do not count a manual refresh as a fix.

## In real life
Polling cost grows with the number of Applications and repos, so teams do tune this value, usually upwards. The
right answer to "too much polling" is webhooks (GitHub, GitLab, Gitea, Bitbucket and others post to
`/api/webhook`; Argo CD refreshes only the Applications whose repo and paths changed), keeping a long
`timeout.reconciliation` as a safety net rather than the main mechanism. Pair the two deliberately and tell
people: a 24h timeout without webhooks makes every GitOps promise false.

## Commands worth remembering
```bash
kubectl -n argocd get configmap argocd-cm -o jsonpath='{.data.timeout\.reconciliation}'
kubectl -n argocd exec argocd-application-controller-0 -- printenv ARGOCD_RECONCILIATION_TIMEOUT
kubectl -n argocd rollout restart statefulset/argocd-application-controller deploy/argocd-repo-server
argocd app get APP --refresh        # normal refresh
argocd app get APP --hard-refresh   # also drops the manifest cache
```

## Common mistakes
- Editing `argocd-cm` and expecting running components to notice.
- Restarting only the controller: the repo-server still caches branch lookups for 24h.
- Settling for a manual refresh after every push.
- Setting the value to `0`/`0s` to "poll constantly".

## Argo CD 2.x vs 3.x
The behaviour is the same in 2.x and 3.x: in stock installs the ConfigMap key reaches the pods through
`valueFrom.configMapKeyRef`, which is read at container start in every version. `timeout.hard.reconciliation`
(a periodic hard refresh that also drops the manifest cache) is off by default in 3.x.
