# Detected As The Wrong Tool

## What broke
The `deploy/` folder contained plain manifests and a leftover `Chart.yaml` (plus a `values.yaml`). Argo CD
looked at the folder, saw a Chart.yaml and decided "this is a Helm chart". A chart without a `templates/` folder
renders nothing, so Argo CD compared an empty desired state with an empty namespace and reported `Synced` and
`Healthy`. The only hint was the tool shown in the Application (Helm) and a resource list with nothing in it.

## Why Argo CD behaves this way
If the Application does not say which tool to use, the repo-server detects it from the files in `source.path`:
`Chart.yaml` means Helm, `kustomization.yaml` (or `kustomization.yml`, `Kustomization`) means Kustomize,
a configured plugin may claim it, and everything else is a plain directory of YAML/JSON. The first match wins,
so the manifests next to the Chart.yaml are simply not read. You can bypass detection by configuring a tool in the
Application: `source.helm`, `source.kustomize`, `source.plugin` or `source.directory`. One catch observed here:
an empty `directory: {}` is dropped when the Application is stored, so it does not force anything; you need at
least one real directory setting such as `recurse: true`.

## The fix
Delete the stray `Chart.yaml` and `values.yaml` from `deploy/` in Git (the folder now holds only what it
claims to hold), or declare the Directory type explicitly in the Application. With automated sync, the objects
are created once the new commit is read.

## In real life
`helm create` in the wrong folder, an example `kustomization.yaml` left from a tutorial, or a Chart.yaml checked in
with a manifest bundle all produce this silent "green but empty" Application. The reverse also happens: a real chart
whose Chart.yaml was renamed is deployed as raw templates and fails on `{{`. When an Application shows zero
resources, check the detected tool before anything else.

## Commands worth remembering
```bash
argocd app get NAME                  # tool and resources
argocd app manifests NAME            # what the detected tool rendered
kubectl -n argocd get app NAME -o jsonpath='{.status.sourceType}'
argocd app set NAME --directory-recurse   # force the Directory type
```

## Common mistakes
- Trusting Synced/Healthy without looking at the resource list.
- `kubectl apply` of the manifests: the pods run, but Argo CD still renders nothing and owns nothing.
- Deleting the files locally and forgetting to commit and push.
- Converting the folder into a chart to "make Helm work": that deploys, but it is not the plain-manifest repo the team wants.
