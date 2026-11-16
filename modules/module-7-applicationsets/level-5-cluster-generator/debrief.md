# Label Me In

## What broke
The ApplicationSet selects clusters with `env: staging`, but the `staging` cluster secret only had a `team`
label. The selector matched nothing, so the generator produced zero parameter sets, and zero Applications.
That is not an error: the set reported "All applications have been generated successfully".

## Why Argo CD behaves this way
The cluster generator enumerates the clusters registered in Argo CD (every Secret labelled
`argocd.argoproj.io/secret-type: cluster`, plus the implicit `in-cluster`) and exposes `name`, `server`,
`metadata.labels` and `metadata.annotations` of each as parameters. A `selector` filters them on the
**labels of the cluster Secret**. An empty result is a valid result, which makes this failure silent. With no
selector at all every cluster matches, including `in-cluster`, which has no Secret and therefore cannot carry
labels: you cannot select it by label, you can only exclude it by selecting something it does not have.
The controller watches cluster secrets, so labelling one regenerates the set immediately.

## The fix
Label the cluster secret: `kubectl -n argocd label secret cluster-staging env=staging`. The Application `quota-staging` appears and deploys to
`name: staging`.

## In real life
Fleets are driven by cluster labels (`env`, `region`, `tier`). Registering a new cluster and forgetting its
labels means it silently receives nothing; that is easy to miss because nothing is red. Cluster secrets are
often created by automation (`argocd cluster add --label`, Cluster API, Terraform), so the label belongs in
that pipeline, not in a manual step. Note that the alias here points at the same API server as `in-cluster`:
two registrations of one cluster is a real pattern for splitting RBAC or namespaces, and selecting the wrong
one deploys twice.

## Commands worth remembering
```bash
argocd cluster list
kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster --show-labels
kubectl -n argocd label secret NAME key=value
```

## Common mistakes
- Removing the selector: `in-cluster` is generated too, so the staging workload runs twice in the same cluster.
- Labelling the Application or a namespace: the generator only reads the labels of the cluster Secret.
- Typing a different key (`environment=staging`): the selector compares exact keys and values.
