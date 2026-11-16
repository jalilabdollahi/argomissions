# Debrief — Stuck In Wave 1

## What broke
Release v1.4 changed the readiness probe of `tracker-api` (sync wave 0) to port 8080, but the container listens on
5678. The new pod never became Ready, so the wave never completed. `tracker-web` (wave 1) and its Service were
never touched and kept serving v1.3, while the sync operation sat in phase Running with the message
`waiting for healthy state of apps/Deployment/tracker-api`.

## Why Argo CD behaves this way
Sync waves are a barrier: Argo CD applies all resources of a wave, then waits until they are all Healthy (using its
built-in health checks, here the Deployment rollout) before it starts the next wave. There is no timeout on that wait
other than Kubernetes' own `progressDeadlineSeconds`, after which the Deployment turns Degraded and the sync fails.
A running operation is also pinned to the revision it started with: pushing a fix does not change a sync that is
already waiting, so the operation has to be terminated and restarted on the new head.
The old ReplicaSet kept serving the whole time (rolling update), which is why this looks like "nothing happened".

## The fix
Correct the probe port in Git, terminate the stuck operation (`argocd app terminate-op`), and sync the new head.
Wave 0 turns Healthy, wave 1 is applied, the operation Succeeds at the head revision.

## In real life
Waves protect you (the dashboard does not roll out against a broken API) but a bad wave-0 resource freezes the whole
release silently for up to ten minutes by default. When a sync "hangs", read `--show-operation` first: the message
names the resource it waits for. A hot-patch with `kubectl` unblocks the wave but leaves Git wrong, and the next
sync brings the bad probe back.

## Commands worth remembering
- `argocd app get APP --show-operation` — phase, revision and the resource the sync is waiting on.
- `argocd app terminate-op APP` — stop a running sync operation.
- `kubectl describe pod` / `kubectl get events --field-selector reason=Unhealthy` — why a pod is not Ready.
- `argocd app sync APP --revision SHA` — sync a specific commit.

## Common mistakes
- Pushing the fix and waiting: the running operation keeps the old revision and never finishes.
- Patching the live Deployment: the wave moves on, but the Application is OutOfSync against Git afterwards.
- Removing the sync-wave annotations to "get past" the wave: the dashboard would then roll out against an API that
  is not ready; the probe, not the ordering, was the bug.

## Argo CD 2.x vs 3.x
Wave and health semantics are unchanged in 3.x; resource tracking switched to annotations by default, which does not
change this scenario.
