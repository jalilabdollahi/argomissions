# Namespace Not Managed

## What broke
The cluster Secret `cluster-regional` listed `namespaces: parcel-eu`. When the US region was added, its
Application pointed at `parcel-us`, a namespace outside that list. Argo CD refused to read or write anything there:
`namespace "parcel-us" for Deployment "parcel-hub" is not managed`.

## Why Argo CD behaves this way
A cluster Secret may restrict Argo CD to a list of namespaces. It then only caches (watches) and manages those, and
refuses any other destination namespace at comparison time, before a single manifest is applied. That is the
point: a tenant-owned cluster, or a ServiceAccount whose RBAC only covers some namespaces, can be registered safely.
Verified on v3.6.1: with a namespaced ServiceAccount and no `namespaces` field, Argo CD tries to list every kind
cluster-wide and the cluster turns `Failed` with `... is forbidden: User "system:serviceaccount:..." cannot list
resource ... at the cluster scope`. So the field is not only a guard rail, it is required for such accounts.
The scope is a second layer next to AppProject `destinations`: the project says where an Application *may* go,
the cluster scope says what Argo CD *can* touch at all.

## The fix
Add the new namespace to the scope (`namespaces: parcel-eu,parcel-us`), either by editing the Secret or with
`argocd cluster set regional --namespace ... --namespace ...`. Nothing else changes: not the Application, not the
ServiceAccount (it already had a Role in `parcel-us`).

## In real life
Every new tenant namespace on a shared cluster meets this error once. Keep three things in step: the namespace,
the RBAC of the ServiceAccount Argo CD uses, and the cluster Secret's `namespaces`. Teams that generate cluster
Secrets from a repo add the namespace in the same pull request as the new Application.

## Commands worth remembering
```bash
argocd cluster list                                   # "(N namespaces)" shows a scoped cluster
argocd cluster get regional -o json | jq .namespaces
argocd cluster set regional --namespace a --namespace b
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
```

## Common mistakes
- Removing the `namespaces` field to "open everything": a namespaced ServiceAccount then fails with `forbidden ... at the
  cluster scope` and every Application on the cluster breaks, not only the new one.
- Pointing the new Application at the old namespace so the error disappears: the US workload then collides
  with the EU one.
- Widening the scope far beyond what the ServiceAccount can access: the cluster cache needs rights in every listed namespace.
