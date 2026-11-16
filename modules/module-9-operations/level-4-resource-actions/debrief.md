# Restart Without kubectl

## What broke
Nothing was out of sync, and that is the point. A ConfigMap consumed through `env`/`valueFrom` is copied into
the container environment when it starts; changing the ConfigMap later does not touch running pods. Argo CD had
done its job (Git and cluster agree), but the pods needed a nudge that is not a configuration change.

## Why Argo CD behaves this way
Argo CD reconciles *state*, not events. A restart is an operation on a live object, so it does not belong in
Git. Argo CD exposes such operations as **resource actions**: small Lua scripts (built in for Deployments,
StatefulSets, DaemonSets, Rollouts, CronJobs and more, or custom ones from `argocd-cm`) that take the live object
and return a modified one, which the API server patches. For Deployments the built-ins are `restart`, `pause`,
`resume` and `scale`. `restart` writes `kubectl.kubernetes.io/restartedAt` into `spec.template.metadata.annotations`,
exactly what `kubectl rollout restart` does, so the Deployment controller rolls the pods. The action runs with
the permissions of the user, checked by Argo CD's RBAC (`actions` resource, `action/apps/Deployment/restart`):
the caller needs no Kubernetes permissions of their own.
The Application stays **Synced**: Git does not set that annotation, and Argo CD does not report fields that
exist only on the live object.

## The fix
`argocd app actions run tollbooth restart --kind Deployment --resource-name tollbooth` (or the Actions menu in the
UI). The rollout replaces both pods and the Service answers the new rate card. Nothing is committed to Git.

## In real life
Config-in-env, mounted files without a reloader, a leaked connection pool, a stuck JVM: "bounce it" is the most
common operational request. Giving people the `restart` action through Argo CD (RBAC: `p, role:oncall, applications,
action/apps/Deployment/restart, */*, allow`) is safer than handing out kubectl, and the audit trail is Argo CD's.
Long-term fixes are a checksum annotation in the pod template (Helm `sha256sum` trick) or a reloader controller,
so that a config change in Git rolls the pods by itself.

## Commands worth remembering
```bash
argocd app actions list APP --kind Deployment --resource-name NAME
argocd app actions run APP restart --kind Deployment --resource-name NAME
kubectl rollout status deploy/NAME
```

## Common mistakes
* Deleting the pods by hand: it works, but needs kubectl rights and leaves no trace in Argo CD.
* Committing a dummy change to Git to force a rollout: the restart is an operation, not desired state.
* Forgetting `--kind` and `--resource-name`: an application has many resources, the CLI must know which one.

## Argo CD 2.x vs 3.x
Verified on v3.6.1: the built-in `restart` action leaves the Application Synced and is attributed to the
`argocd-server` field manager (a `kubectl rollout restart` shows up as `kubectl-rollout`). Running an action is
governed by the `actions` RBAC permission, which `admin` has.
