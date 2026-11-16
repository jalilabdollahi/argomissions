# The Parameter That Wins

## What broke
Nothing was out of sync, and that was the problem. The Application carried
`spec.source.helm.parameters: [{name: release.version, value: 1.9.1-hotfix}]`, a leftover from an incident.
Helm parameters are applied as `--set release.version=1.9.1-hotfix`, and `--set` always beats values files.
Git moved on to `2.1`, the rendered manifests did not change, so Argo CD correctly reported Synced and Healthy.

## Why Argo CD behaves this way
Argo CD builds one `helm template` call from the Application: value files first, then `valuesObject`/`values`,
then `parameters` (so a parameter overrides everything above it). The result is what Git "means" **for this
Application**. Overrides on the Application are part of the desired state, they just do not live in the repo.
Synced only says "live equals what these inputs render", never "live equals what values.yaml says".

The tell-tale signs are `Helm Parameters:` in `argocd app get`, and a *Parameters* tab in the UI that shows
values in bold when they come from the Application instead of Git.

## The fix
Remove the override: `argocd app unset media-gateway -p release.version` (or delete the `parameters` list from the
Application YAML). Git values win again and automated sync rolls out the version Git declares.

## In real life
Parameters set through `argocd app set` or the UI are the classic "temporary" hotfix that nobody removes. They are
invisible in code review, survive every release, and show up weeks later as "why does my values change do nothing?".
Teams keep Applications in Git (so a parameter shows up in a pull request) and treat any `helm.parameters` entry as
technical debt with an owner.

## Commands worth remembering
```bash
argocd app get media-gateway                      # shows Helm Parameters
argocd app manifests media-gateway                # what Argo CD actually renders
argocd app unset media-gateway -p release.version # drop one parameter
argocd app set media-gateway -p release.version=2.1   # (the way the override was created)
```

## Common mistakes
- Editing `values.yaml` again and again: the Application parameter still wins on every render.
- Copying the hotfix value into Git so the two "match": the incident leaves the repo and the next release is stuck on it.
- Trusting Synced/Healthy as proof that the intended version runs: check what the manifests actually render.
