# Synced But Sick

## What broke
The release contained a typo in the image tag: `hashicorp/http-echo:1.O` (a capital letter O) instead of
`1.0`. The kubelet could not pull it (`ErrImagePull`, then `ImagePullBackOff`), the Deployment never got a ready
pod and, with `progressDeadlineSeconds: 30`, it reported `ProgressDeadlineExceeded`. Argo CD showed the
Application as `Synced` and `Degraded` at the same time.

## Why Argo CD behaves this way
Argo CD keeps two independent verdicts:

* **Sync status** answers "does the live state match Git?". Here it did: the broken Deployment *is* exactly what
  Git describes, so the answer is `Synced`.
* **Health status** answers "is what is running actually working?". Argo CD derives it from the resources:
  Deployments are healthy when the rollout is complete and available, `Degraded` when the Progressing condition
  reports a timeout, `Progressing` while it is still within the deadline.

A sync *operation* succeeds when the manifests were applied, not when the workload came up. Argo CD does not
wait for rollouts unless a hook or `argocd app wait --health` makes you. Note the delay: a Deployment is
`Progressing` until its deadline passes (default 600 s), which is why this mission lowers the deadline.

## The fix
Correct the tag in Git, push, sync. The new ReplicaSet pulls a real image, the rollout completes and health
turns `Healthy`. Patching the image on the live Deployment would get the pod running, but Git would still hold
the typo, the Application would be `OutOfSync` and the next sync would break production again.

## In real life
"The sync was green" is one of the most common sentences in post-mortems. Treat `Synced` as "delivered" and
`Healthy` as "working": alert on health, use `argocd app wait --health` in pipelines, and consider sync
`PostSync` hooks or Argo Rollouts for real verification. Image typos, missing pull secrets and wrong tags are all
invisible to a sync.

## Commands worth remembering
```bash
argocd app get notifier                    # sync AND health, per resource
argocd app wait notifier --health          # block until healthy (or time out)
kubectl -n messaging describe pod          # events: the real reason
kubectl -n messaging rollout status deploy/notifier
kubectl -n messaging get deploy notifier -o jsonpath='{.status.conditions}'
```

## Common mistakes
- Reading `Synced` as "it works" and closing the ticket.
- `kubectl set image` on the live Deployment: the pod runs, but the Application is OutOfSync and Git still
  holds the typo.
- Fixing Git and not syncing: a manual Application does not deploy by itself.

## Argo CD 2.x vs 3.x
Health assessment of Deployments and the sync/health split are unchanged between 2.x and 3.x.
