# Inline Values, Ignored

## What broke
The Application's `helm.valuesObject` wrapped the production settings in a `search-suggest:` key, the way you would
address a **subchart** or an umbrella chart's dependency. This chart is not an umbrella chart: its templates read
`.Values.replicaCount` and `.Values.banner` at the top level. Helm does not complain about unknown keys, so it
rendered the defaults, Argo CD found nothing to change, and the Application stayed Synced and Healthy.

## Why Argo CD behaves this way
`valuesObject` (and its string twin `values`) is injected as one more values file, after the files in
`valueFiles` and before `parameters`. It is merged into the chart's `values.yaml`. Argo CD does not validate
it against the chart: there is no schema unless the chart ships a `values.schema.json`. A typo or an extra
level of nesting is therefore not an error, only a no-op. `values` is a string (a YAML document inside YAML),
`valuesObject` is real YAML, which is easier to review and to patch.

## The fix
Put the keys where the chart reads them: top level of `valuesObject`. The rendered Deployment changes, the
Application turns OutOfSync, and a sync rolls out 3 replicas and the production banner. Editing the chart
defaults would also render correctly, but it would defeat the team's decision to keep environment values in the
Application and would deploy production settings on every `helm install` from a laptop.

## In real life
Wrong nesting and wrong key case (`replicaCount` vs `replicas`) are the top reasons for "my values are ignored".
The reflex is to check the render, not the status: `argocd app manifests APP` or `argocd app diff APP`, and
`helm template` locally with the same values. Charts with `values.schema.json` turn such mistakes into errors.

## Commands worth remembering
```bash
argocd app manifests search-suggest | grep -E "replicas|text"
kubectl -n argocd get application search-suggest -o jsonpath='{.spec.source.helm}'
helm template search-suggest chart -f my-values.yaml
argocd app diff search-suggest
```

## Common mistakes
- Trusting Synced and Healthy: the Application was green the whole time.
- Scaling the Deployment with `kubectl`: it hides one symptom, leaves the banner wrong and the Application OutOfSync.
- Copying the production settings into `chart/values.yaml`: it works, but it moves the environment out of the place the team chose.
