# Debrief — Migration Job Forbidden

## What broke
Release v4.1 added a PreSync migration Job and, in the same commit, widened the `migrator` Role so the Job may create
a ConfigMap. The Job ran with the old Role and was denied by the API server (HTTP 403). The new Role never arrived,
because it is part of the Sync phase, which only starts after PreSync hooks have succeeded: a deadlock that can only be
broken by changing the order.

## Why Argo CD behaves this way
A sync runs PreSync hooks, then the Sync phase (resources ordered by wave), then PostSync hooks. Waves only order
resources within one phase: a resource with `sync-wave: "-100"` is still in the Sync phase, after every PreSync hook.
So anything a hook depends on (ServiceAccount, Role, RoleBinding, ConfigMap, Secret) must either be a hook of an earlier
phase/wave itself, or the hook must be moved into the Sync phase after those resources. RBAC objects used as PreSync hooks
need `hook-delete-policy: BeforeHookCreation` (or none) so they stay after the sync; `HookSucceeded` would delete the Role
the moment it was created.

## The fix
Role and RoleBinding become PreSync hooks in wave -1 (earlier than the Job in wave 0), so the permission exists when
the migration starts. The equivalent alternative: keep them as normal resources in wave -2, turn the Job into a Sync hook
in wave -1, and leave the Deployment in wave 0. Either way the sync order is: permissions, migration, rollout.

## In real life
This is the standard way for first-run and "new permission" releases to fail: the first install has no ServiceAccount
yet, and later releases change a Role in the same commit as the code that needs it. Hooks need the same dependencies as
any workload, so write down the order: namespace and RBAC, config, migrations, rollout.

## Commands worth remembering
- `argocd app get APP --show-operation` — which hook failed, in which phase.
- `kubectl -n NS logs job/NAME` — the real API error (for example `... is forbidden: User "system:serviceaccount:..."`).
- `kubectl auth can-i create configmaps --as system:serviceaccount:NS:SA -n NS` — check a Role from your terminal.

## Common mistakes
- Applying the Role by hand with `kubectl`: the sync succeeds once, and the next permission change deadlocks the same way.
- Making the RBAC objects PreSync hooks without a lower wave than the Job: they race the Job.
- Using `hook-delete-policy: HookSucceeded` on the RBAC hooks: the Role is deleted right after it was created.

## Argo CD 2.x vs 3.x
No behavioural change for waves and hooks in 3.x.
