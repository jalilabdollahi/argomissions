# Green Dashboard, Red Backups

## What broke
Nothing was broken in the sense of an error: Argo CD simply had no idea what "healthy" means for a `Backup`.
The `vaultline` application synced fine, every object existed, and so the dashboard stayed green while the
operator reported `phase: Failed` in the status of `nightly-ledger`. A silent failure that looks like success is
worse than a loud one.

## Why Argo CD behaves this way
Health in Argo CD is computed per resource by a *health check*. Argo CD ships checks (Lua scripts) for the
built-in kinds (Deployment, StatefulSet, Ingress, Job, PVC ...) and for a few popular CRDs (Rollouts,
cert-manager, Crossplane ...). For a kind with no check it cannot guess what the fields in `.status` mean, so
the resource has no health at all and counts as Healthy for the application. In Argo CD 3.x the per-resource
health is no longer stored in the Application object: `kubectl get application -o yaml` shows resources
without health, while `argocd app get -o json` (the resource tree, the UI) shows it.

You describe the semantics yourself in `argocd-cm`: `resource.customizations.health.<group>_<Kind>` holds a Lua
script that receives the live object as `obj` and returns `status` (`Healthy`, `Progressing`, `Degraded`,
`Suspended`, `Missing`) and an optional `message`. The application health is the worst of its resources
(Degraded beats Progressing beats Healthy). The controller reloads argocd-cm live, but an application only gets
a new health the next time it is reconciled, so refresh it.

## The fix
Add a Lua health check for `vaultline.argomissions.io_Backup`: `Done` is Healthy, `Failed` is Degraded,
anything else (and no status yet) is Progressing. After the next refresh Argo CD reports `nightly-ledger`
Degraded and the application Degraded. The failed backup is not fixed by this, it is *visible*. You must not
"fix" the dashboard by editing the operator's status or by returning Healthy for everything.

## In real life
Every team that adopts an operator without a bundled health check runs into this: sync waves that never wait
(a wave only waits for Healthy resources, and a CR without a check is Healthy immediately), `argocd app wait
--health` returning too early, alerts on `argocd_app_info{health_status="Degraded"}` that never fire. The
Argo CD repo has a `resource_customizations` directory of community scripts you can copy from. Keep the Lua in Git
(Argo CD can manage its own argocd-cm) and test it offline before it reaches production.

## Commands worth remembering
```bash
argocd app get APP -o json | jq '.status.resources[] | {kind,name,health}'
argocd admin settings resource-overrides health obj.yaml --argocd-cm-path cm.yaml
argocd app get APP --refresh
kubectl -n argocd get cm argocd-cm -o yaml
```

## Common mistakes
* Editing `.status` of the custom resource (or the Application) to get a green dashboard: the operator owns
  `.status`, and the failure is still there.
* Reading `kubectl get application -o yaml` to check the result: in 3.x the per-resource health is only in
  `argocd app get -o json` / the UI.
* Forgetting the `nil` check: `obj.status` is absent until the operator reports once, and a Lua error makes
  the resource show a health message about the script instead of a state.

## Argo CD 2.x vs 3.x
In 2.x the health of each resource was stored in `status.resources[].health` of the Application object; in 3.x
it only lives in the resource tree (`argocd app get -o json`, UI, API). The older combined key
`resource.customizations` (group/Kind with `health.lua`) still works in 3.x, but the per-kind keys
`resource.customizations.health.<group>_<Kind>` are the documented form.
