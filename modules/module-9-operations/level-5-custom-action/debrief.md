# A Button For Maintenance

## What broke
Nothing was broken: a recurring operational task (switch maintenance mode on or off around a release) lived in a
shell history, and it needed kubectl access that the security team wanted to take away. The task is not a
desired state, so it does not belong in Git either: it is an *operation* on a live object.

## Why Argo CD behaves this way
Argo CD resource actions are Lua scripts attached to a resource kind. For a kind, `argocd-cm` key
`resource.customizations.actions.<group>_<Kind>` holds:

* `discovery.lua`: receives the live object as `obj` and returns the actions that apply, each with a `disabled`
  flag. The UI and `argocd app actions list` call it every time they show the menu, so it can follow the
  object's state (here: `maintenance-on` is disabled while maintenance is on).
* `definitions`: for each action an `action.lua` that mutates `obj` and returns it. Argo CD patches the result
  to the cluster as the `argocd-server` field manager, using the permissions of Argo CD, while checking *your* RBAC
  (`action/apps/Deployment/maintenance-on`).

Built-in actions (restart, pause, scale ...) are only kept when you set `mergeBuiltinActions: true`; otherwise a
custom definition for that kind replaces them, a classic surprise. The Application stays Synced: the annotation is
not in Git, and Argo CD does not report fields that only exist on the live object. Everything is read live from
`argocd-cm`.

## The fix
Define `maintenance-on` and `maintenance-off` with `mergeBuiltinActions: true`, nil-safe Lua for annotations and a
discovery script that disables the no-op action. Then run `maintenance-on` through Argo CD.

## In real life
Typical custom actions: promote or abort a Rollout, suspend and resume a CronJob, trigger a Job from a CronJob,
rotate a certificate, flip a feature flag, cordon traffic. Each gives on-call a safe, audited, RBAC-controlled
button instead of cluster credentials. Keep the Lua small, put `argocd-cm` in Git, test with
`argocd admin settings resource-overrides run-action` before it reaches production.

## Commands worth remembering
```bash
argocd app actions list APP --kind Deployment --resource-name NAME
argocd app actions run APP ACTION --kind Deployment --resource-name NAME
argocd admin settings resource-overrides run-action obj.yaml ACTION --argocd-cm-path cm.yaml
kubectl -n argocd get cm argocd-cm -o yaml
```

## Common mistakes
* Forgetting `mergeBuiltinActions: true`: `restart` and `scale` vanish from the menu.
* Indexing `obj.metadata.annotations[...]` without a nil check: a Deployment without annotations makes the Lua fail.
* Committing the flag to Git so that Argo CD "owns" it: then there is nothing to toggle, only commits.

## Argo CD 2.x vs 3.x
Custom actions are defined the same way in 2.x and 3.x. Verified on v3.6.1: `argocd-cm` changes are picked up live
(no restart), the action patch is attributed to the `argocd-server` field manager, and without
`mergeBuiltinActions: true` the custom definition replaces the built-in actions of that kind.
