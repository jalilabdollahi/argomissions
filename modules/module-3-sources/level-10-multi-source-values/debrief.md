# Values From Another Repo

## What broke
Application `pricing` has two sources: the Helm chart in `pricing-charts` and a second repo, `pricing-env`, that
only exists to supply a values file. The chart source referred to the values as `$values/prod/values.yaml`,
but the environment repo was declared with `ref: env`. Argo CD could not resolve `$values` and refused to render
anything: `source referenced "$values", which is not one of the available sources ($env)`.

## Why Argo CD behaves this way
Since Argo CD 2.6 an Application can have a list of `sources`. A source with a `ref` is not rendered: it is
cloned and made available to the other sources as `$<ref>`. Helm's `valueFiles` can then point into it
(`$values/prod/values.yaml`). The name is a plain string match between the `ref` and the `$` prefix, there is no
fallback and no guessing, so a mismatch is a hard `ComparisonError`: the repo-server cannot produce a target
state, the sync status becomes Unknown and nothing reaches the cluster. The comparison also tracks one
revision per source (`argocd app get` shows both), so a change in either repo makes the Application OutOfSync.

## The fix
Make the two names agree (`ref: values` or `$env/...`), refresh and sync. The values stay in the environment
repo, the chart stays in the chart repo.

## In real life
Separating chart code from environment values lets a platform team ship charts while app teams own their values
repos and PR reviews. The cost is exactly this kind of wiring. Typos in ref names and file paths are common,
and a value file path that is wrong gives a different error (the file is not found), so read the condition text.
Pasting the values into the Application "to make it work" re-creates the drift Git was supposed to remove.

## Commands worth remembering
```bash
argocd app get NAME                         # conditions, one revision per source
kubectl -n argocd get application NAME -o jsonpath='{.spec.sources}' | jq
argocd app manifests NAME                   # what the chart renders with the values
helm template charts/pricing -f ../pricing-env/prod/values.yaml   # local check
```

## Common mistakes
- Putting values inline in the Application (`helm.values`): it works, but the values leave Git.
- Pointing at `staging/values.yaml` to get a green sync: Synced does not mean the right environment.
- Fixing the names but not syncing: the Application stays OutOfSync and nothing runs.
