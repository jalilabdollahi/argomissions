# ClusterRole Forbidden

## What broke
The manifests in Git contained a ClusterRole and a ClusterRoleBinding. The `radar` project had an empty
`clusterResourceWhitelist`, so the sync was rejected before anything was applied: `resource
rbac.authorization.k8s.io:ClusterRole is not permitted in project radar`.

## Why Argo CD behaves this way
Namespaced and cluster-scoped objects are governed by different lists. For namespaced kinds a project has
`namespaceResourceBlacklist` (everything allowed except what is listed) and optionally
`namespaceResourceWhitelist`. For cluster-scoped kinds the default is the opposite: **nothing is allowed**
unless it is in `clusterResourceWhitelist` (or not in `clusterResourceBlacklist` when only a blacklist is used).
That is deliberate, because a ClusterRole, a Namespace or a CRD can affect every team. Argo CD validates the
whole sync up front, which is why the Deployment was not created either: one forbidden object fails all.

## The fix
Whitelist the two kinds by group and kind: `argocd proj allow-cluster-resource radar rbac.authorization.k8s.io
ClusterRole` and the same for `ClusterRoleBinding`, then sync again. Allowing only `ClusterRole` leaves the
binding refused, so the sync still fails.

## In real life
Operators, agents and monitoring stacks ship cluster RBAC and CRDs. Each team's project should list exactly the
kinds its app needs; `group: '*', kind: '*'` turns the team into cluster admins, because a ClusterRoleBinding to
`cluster-admin` is just another object in Git. Treat whitelist changes as security reviews.

## Commands worth remembering
```bash
argocd proj get radar
argocd proj allow-cluster-resource radar GROUP KIND
argocd proj deny-cluster-resource radar GROUP KIND
kubectl -n argocd get appproject radar -o jsonpath='{.spec.clusterResourceWhitelist}'
argocd app sync radar-agent
```

## Common mistakes
- Whitelisting `*` / `*`: every cluster-scoped kind is now allowed for this team.
- Allowing the ClusterRole but forgetting the ClusterRoleBinding (same message, one kind shorter).
- Moving the Application to `default` or deleting the RBAC from Git: the agent then cannot read nodes.
