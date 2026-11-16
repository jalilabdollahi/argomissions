# Cluster Not Found

## What broke
The Application's destination was `https://kubernetes.default.svc.cluster.local`. That is a perfectly valid
DNS name of the Kubernetes API from a pod, but it is not what Argo CD has registered as a cluster. Argo CD
refused to even compare: `InvalidSpecError: error getting cluster by server ... not found`.

## Why Argo CD behaves this way
Argo CD deploys only to **registered clusters**. Each is a Secret (labelled
`argocd.argoproj.io/secret-type: cluster`) holding a name, a server URL and credentials; the cluster Argo CD
runs in is registered automatically as `in-cluster` with the server `https://kubernetes.default.svc`.
`spec.destination` is looked up in that list: by `server` (exact string match, no DNS or alias resolution) or
by `name`, never both. It is a lookup key, not a network address, so two names for the same API server are two
different clusters to Argo CD, and an unregistered one is invalid.

Because the spec is invalid, the Application never gets as far as rendering manifests: it stays `Unknown`.

## The fix
Use the registered destination: `server: https://kubernetes.default.svc` or `name: in-cluster`, then sync.
`argocd cluster list` is the source of truth for the strings.

## In real life
This shows up when a repo of Application manifests is copied from another environment (a dev cluster URL that
no longer exists), after a cluster is renamed or re-registered, or when someone "improves" the URL. Registering
external clusters (`argocd cluster add`) and using `destination.name` makes manifests portable: the name is
the same on every Argo CD, only the registration differs per environment.

## Commands worth remembering
```bash
argocd cluster list
argocd app get NAME
argocd app set NAME --dest-server URL     # or --dest-name NAME
kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster
```

## Common mistakes
- Guessing another name (`destination.name: kubernetes`) or another spelling of the URL: only registered
  clusters match.
- Setting both `name` and `server` in the destination: Argo CD accepts only one.
- Changing the destination but not syncing: the Application is OutOfSync until someone syncs it.
