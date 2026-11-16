# The Test That Fails The Sync

## What broke
Nothing in the application. After every sync Argo CD runs the PostSync hook Job `booking-web-smoke-test`, and
that test called `http://booking-web:8080/`. The Service exposes port 80, the curl failed, the Job failed, and
Argo CD marked the whole sync operation `Failed`, although the resources were applied and healthy. The CI job
that waits for a green sync was red for a bug in the test.

## Why Argo CD behaves this way
Hooks are part of the sync operation. `PostSync` hooks run after all resources of the sync are applied and
Healthy; the operation only succeeds when every hook succeeded. That is the point of a hook-based smoke test:
a bad release does not get a green sync. The cost is that a bad *test* does as well. The Application's sync
status (`Synced`) and the operation phase (`Failed`) are different things: the first says the cluster matches
Git, the second says the last sync run did not complete. The failed hook Job and its pod stay in the namespace
(`kubectl logs`) so you can read why.

## The fix
Fix the test in Git: call the Service on its real port. Then sync again; with `BeforeHookCreation` Argo CD
replaces the old Job and runs the test against the live Service. Do not delete the hook, and do not make
it unable to fail: both turn the sync green and remove the safety net that was the reason for the hook.

## In real life
Smoke-test hooks are common (call the health endpoint, run a canary request, check a migration result), and
most of their failures are test bugs: wrong port, service name from another namespace, a hook that runs before
DNS or endpoints are ready, a missing `--fail` flag so curl exits 0 on a 500. Give tests `backoffLimit`, a time
limit, and clear output; keep them quick so that they do not hold up every sync.

## Commands worth remembering
```bash
argocd app get NAME                   # operation phase + hooks
kubectl -n NS logs job/NAME           # the hook's own output
kubectl -n NS get svc,endpoints
argocd app sync NAME --refresh
```

## Common mistakes
- Deleting the smoke test, or appending `|| true`: the sync is green again and so is the next broken release.
- Changing the application to fit a wrong test, for example exposing an extra port nobody uses.
- Reading `Synced` as "the last sync worked": check the operation phase too.
