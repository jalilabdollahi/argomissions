# The Migration That Ate Monday

## What broke
Release v7 of `shiftboard` carried four independent mistakes, and a sync only shows the first one it hits:
a migration hook whose finished run was never cleaned up (the pod template changed, the Job is immutable), RBAC
for the migration that arrives in the same release but *after* it, a custom resource using a field the CRD in the
cluster does not have yet (the CRD lives in a separate Application with manual sync), and a PostSync smoke test
that curled a Service name that does not exist.

## Why Argo CD behaves this way
A sync runs in phases: PreSync hooks, the sync phase in sync-waves, PostSync hooks. A hook is a normal Kubernetes
object created by Argo CD for the phase, and what happens to it afterwards is the **hook delete policy**:
`HookSucceeded`, `HookFailed`, `BeforeHookCreation`. With only `HookFailed`, a successful Job stays, and because a
Job's pod template is immutable the next release that changes it is refused. `BeforeHookCreation` deletes the old
run just before the new one is created and keeps the last run for debugging.
Regular resources (Role, RoleBinding) are applied in the *sync* phase, so they can never be ahead of a PreSync
hook. To order them first they have to be hooks too (PreSync with an earlier wave) or the migration has to move
into the sync phase after them. A failed hook stops the whole sync: later phases never run, so faults hide
behind each other.
Two Applications are two independent sync operations. Nothing orders `rota-crds` before `shiftboard`; a CRD
that is not updated does not know the new field of its instances: the API server prunes it silently, the sync
"succeeds" and the instance is OutOfSync forever, which is easy to "fix" with ignore rules that merely hide it.

## The fix
`BeforeHookCreation` on the migration Job; ServiceAccount, Role and RoleBinding as PreSync hooks in wave -1;
automated sync for `rota-crds` so the CRD follows Git; the smoke test pointing at Service `shiftboard`.

## In real life
This is the classic release-day pile-up: the migration works in staging because staging was installed by the
previous release, the extra permission "is in Git" but not yet in the cluster, the CRD team ships in another
pipeline, and the smoke test was written against a Service that was renamed. The post-mortem question is never
"who forgot", it is "why does the pipeline need someone to remember": every ordering rule that lives in a runbook
instead of in sync phases, waves and sync policies will be forgotten once.

## Commands worth remembering
```bash
argocd app get APP --show-operation      # which phase / which hook failed
argocd app diff APP
kubectl -n NS logs job/NAME; kubectl -n NS get events --sort-by=.lastTimestamp
argocd app set APP --sync-policy automated
argocd app history APP
```

## Common mistakes
- Deleting the hook Job by hand to get one more sync through: the next release fails the same way.
- Adding `ignoreDifferences` for the ShiftPolicy to make the Application look Synced: the new field is still
  missing from the live object and nothing enforces the policy.
- Making the smoke test pass with `|| true`: the gate is gone and the next real outage ships.

## Argo CD 2.x vs 3.x
Two things differ from older write-ups. The error for a left-over hook Job is the *immutable pod template* of an
existing object (3.x patches the existing hook instead of failing with `already exists`). And a CRD together with
its custom resources in the *same* Application needs no wave on 3.6.1: Argo CD applies the CRD before instances of
it even when the instance carries an earlier wave. The ordering problem remains for CRDs that arrive another way,
as here.
