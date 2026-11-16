# Update Is Not Delete

## What broke
The on-call role had `applications, update` and (in the old setup) everything worked, so nobody wrote down which
permission powered which button. After the move to Argo CD 3.x the same policy still lets mira edit the
Application, but "Restart" and "Delete pod" answer `permission denied`.

## Why Argo CD behaves this way
Before 3.0, `update` and `delete` on an application were also checked for the *resources* the application
manages: patching a live resource, running a resource action, deleting a Pod. That made it impossible to give
someone "edit the Application settings" without also letting them delete workloads. 3.0 made it fine-grained:

* `update` / `delete` apply to the Application object only.
* `update/<group>/<kind>/<namespace>/<name>` and `delete/<group>/<kind>/<namespace>/<name>` apply to managed
  resources (`*` works in every segment; `update/*` and `delete/*` bring back the old breadth).
* Running a resource action is its own permission, `action/<group>/<kind>/<action>`, for example
  `action/apps/Deployment/restart`.

Verified on v3.6.1: with only `update` the restart action and a Pod delete both return 403, `action/...` alone
allows the action without `update`, and RBAC is evaluated before the resource is looked up, which is how you can
probe a policy safely with a resource name that does not exist (404 means allowed, 403 means denied).

## The fix
Add the two precise policies to the role: the `restart` action on Deployments and deletion of Pods in the
project's applications. Wildcards (`action/*`, `delete/*`) would also work for the symptom but would let her
delete Secrets and run `scale` or any custom action.

## In real life
This is the first thing that breaks after an Argo CD 3.x upgrade for teams that gave "developers" `update`.
The audit is mechanical: for every role with `update` or `delete`, decide whether the people also need the
`/*` form, and write down the reason. UI buttons map to the policies: Restart and other actions need `action/...`,
deleting a resource from the resource tree needs `delete/...`, "Edit" on a live manifest needs `update/...`.

## Commands worth remembering
```bash
argocd account can-i update applications 'loyalty/rewards-engine'      # application-level only
argocd app actions list APP --kind Deployment --group apps --resource-name NAME
argocd app actions run APP restart --kind Deployment --group apps --resource-name NAME
argocd app delete-resource APP --kind Pod --resource-name NAME
kubectl -n argocd get cm argocd-rbac-cm -o yaml
```
`argocd account can-i` cannot express sub-resources: test them with the real action, or with a non-existent name.

## Common mistakes
- Adding `update/*` and expecting restart to work: actions are not covered by it.
- Adding `delete/*` and `action/*` "to be safe": Secrets, Deployments and every custom action become available.
- Giving the person `role:admin` because the policy syntax is unfamiliar.

## Argo CD 2.x vs 3.x
In 2.x `update` and `delete` on an application implied permission on its managed resources. In 3.x they do not:
the sub-resource forms `update/*` and `delete/*` must be granted explicitly, and actions need `action/*` rules.
Existing 2.x policies keep working for the Application object and silently stop covering the rest.
