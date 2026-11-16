# Values Not Found

## What broke
The Application listed `valueFiles: [values-prod.yaml]`, but the chart folder only contains
`values-production.yaml`. The repo-server runs `helm template` with `--values .../chart/values-prod.yaml`,
Helm cannot open the file and the whole render fails. With no rendered manifests there is nothing to compare,
so the Application is `Unknown` with a `ComparisonError`, and nothing was ever deployed.

## Why Argo CD behaves this way
Argo CD does not interpret Helm; it runs the `helm` binary inside the repo-server, exactly as you would run
`helm template NAME PATH -f FILE --namespace NS`. The release name is the Application name, the namespace is the
destination namespace, and every entry of `helm.valueFiles` becomes a `--values` argument. File names are
resolved **relative to the Application's `path`** (here `chart/`), not to the repository root, and they must
exist in the checked-out revision. A missing file is a hard error, because silently skipping a values file could
deploy a production service with development settings.

There is an escape hatch, `helm.ignoreMissingValueFiles: true`, meant for patterns like
`values-$ENV.yaml` where a file legitimately may not exist for every environment. Using it here would
have hidden the typo: Synced, Healthy, and running the laptop defaults.

## The fix
Make the Application and the repo agree: `argocd app set weather-api --values values-production.yaml`
(or rename the file in Git). Then the chart renders with the production overrides and automated sync deploys it.

## In real life
This is the most common Helm-on-Argo-CD failure: a file renamed in a refactor, a values file added on a branch
that the Application does not track yet, or a path written relative to the repo root. The cure is to reproduce
the exact render locally before pushing: `helm template NAME PATH -f PATH/values-x.yaml`.

## Commands worth remembering
```bash
argocd app get weather-api                  # conditions show the helm error
argocd app set weather-api --values FILE    # replace the valueFiles list
argocd app manifests weather-api            # what Argo CD rendered
helm template weather-api chart -f chart/values-production.yaml
```

## Common mistakes
- Setting `ignoreMissingValueFiles`: the error disappears and the defaults are deployed instead.
- Writing the value file path relative to the repository root (`chart/values-production.yaml`) instead of the Application path.
- Hand-applying `helm template` output with kubectl: it works once, and Argo CD still shows the Application as broken.
