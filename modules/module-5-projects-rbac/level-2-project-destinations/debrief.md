# Destination Not Permitted

## What broke
`rx-dispatch` asked to deploy into namespace `pharmacy` of the local cluster, and its project only allowed
namespaces matching `clinic-*`. Argo CD answered with `InvalidSpecError ... do not match any of the allowed
destinations in project 'clinic'` and did not even try to render the manifests.

## Why Argo CD behaves this way
An AppProject's `destinations` is a list of (cluster, namespace) pairs, each side a glob. The cluster is
given by `server` or by `name`, the namespace by `namespace`. An Application may only deploy where at least
one entry matches both. It is the main guard that stops one team's Application from writing into another
team's namespace, or into `kube-system`. As with `sourceRepos` the check runs on the Application spec, so the
symptom is an `Unknown` sync status and a condition, not a failed sync.

## The fix
Teach the project the destination: `argocd proj add-destination clinic https://kubernetes.default.svc pharmacy`.
An exact namespace is the safest; a glob such as `pharmacy*` is fine when a team owns a family of namespaces.

## In real life
Naming conventions (`team-*`) are how platform teams keep projects small. When a team needs a namespace that
breaks the convention, the answer is a reviewed one-line change to the project, not `namespace: "*"` and not
parking the app in `default`. Also remember that destinations check namespaced objects: a manifest that carries
its own `metadata.namespace` is checked against the project too.

## Commands worth remembering
```bash
argocd proj get clinic
argocd proj add-destination clinic SERVER NAMESPACE
argocd proj remove-destination clinic SERVER NAMESPACE
kubectl -n argocd get appproject clinic -o jsonpath='{.spec.destinations}'
```

## Common mistakes
- Changing the Application to `clinic-pharmacy` so it fits the project: a new namespace nobody asked for.
- `namespace: "*"` (or server `*`) in the project: the team can now deploy into `kube-system` and `argocd`.
- Moving the Application to `default`: no fence at all.
