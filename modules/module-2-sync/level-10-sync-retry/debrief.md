# Flaky First Contact

## What broke
The Application ships a `SensorProfile` custom resource, but the CRD that defines that kind was installed by a different
process that finishes minutes later. Argo CD validates a sync before applying anything (a dry-run per resource); a kind
the API server does not know fails validation, so the whole sync applied nothing. The Application had a retry policy, but
a tight one (two attempts, 5 s then 10 s), so it gave up long before the CRD existed and sat in `SyncError`.

## Why Argo CD behaves this way
A sync operation is one attempt to reach the desired state. When it fails, Argo CD does **not** start another one on its
own for the same commit; that would hammer the API server over errors that need a human. `syncPolicy.retry` is the
explicit opt-in: `limit` attempts, waiting `duration`, multiplied by `factor` each time, capped at `maxDuration`
(`limit: -1` never stops). Changing the policy does not revive an operation that already failed, so a new sync has to be
started once.

Be explicit about the alternative: Argo CD can order things for you inside one Application with sync waves
(`argocd.argoproj.io/sync-wave`) and skip the missing-kind dry-run with `SkipDryRunOnMissingResource=true`, but only when the
CRD is part of the same sync. When the CRD comes from elsewhere (an operator, another Application, a bootstrap job), time
is the only dependency and retry-with-backoff is the tool.

## The fix
Give the Application a retry policy that outlasts the dependency, for example `limit: 8`, `duration: 10s`, `factor: 2`,
`maxDuration: 1m` (about six minutes), and start a sync. Once the CRD is established an attempt passes validation and
the Application becomes Synced and Healthy. Git did not change: this is a policy problem, not a manifest problem.

## In real life
Fresh clusters are full of these races: operators and their CRs installed by different Applications, namespaces created by
another tool, webhooks that are not ready yet, cert-manager issuers right after cert-manager. Retry with backoff turns
"red for ten minutes after a cluster rebuild" into "green by itself". Pick the window from how long the dependency can
really take; a limit of -1 hides a genuinely broken dependency, so alert on a long-running retry instead.

## Commands worth remembering
```bash
argocd app get APP                                  # last operation, retry count, per-resource messages
argocd app set APP --sync-retry-limit N --sync-retry-backoff-duration 10s \
  --sync-retry-backoff-factor 2 --sync-retry-backoff-max-duration 1m
kubectl -n argocd get application APP -o jsonpath='{.spec.syncPolicy.retry}'
kubectl get crd | grep NAME
```

## Common mistakes
- Waiting for the CRD and syncing by hand: green today, the same red the next time a cluster is rebuilt.
- Adding a few more attempts without doing the arithmetic: 4 attempts at 5 s is still under a minute.
- Committing something to Git "to trigger a sync": the manifests were never the problem.

## Argo CD 2.x vs 3.x
The curriculum premise "without retry the app stays failed until the next commit" is only partly true on Argo CD 3.6.1:
an automated sync without any `retry` block already gets a built-in retry (`limit: 5`, 5 s doubling up to 3 min, roughly
two and a half minutes), which we observed on the operation of an Application that had none. That default is shorter than
a slow dependency, and an explicit `retry` block replaces it, which is why this level starts with a tight explicit policy.
