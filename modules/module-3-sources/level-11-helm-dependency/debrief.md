# Missing Subchart

## What broke
Chart `notify` declared a dependency on the library chart `notify-common` with `repository: file://../notify-commons`.
The directory is called `notify-common`, so the path pointed nowhere. Before rendering, Argo CD runs
`helm dependency build` on the chart, which failed with `Error: directory ../notify-commons not found`. No
manifests could be generated, the Application stayed at sync status Unknown and nothing was deployed.

## Why Argo CD behaves this way
A Helm chart in Git is not self-contained when it has `dependencies`: Helm needs the subcharts in `charts/`
before `helm template` can resolve their named templates. The repo-server therefore runs `helm dependency build`
(it also resolves `file://` paths relative to the chart directory, inside the cloned repo). Errors from that
step are shown unchanged as a `ComparisonError`, which is why the message looks like a Helm CLI error. For
remote chart repositories the same step needs network access and credentials (`argocd repo add ...`); for
`file://` it only needs the path to be right. If a `Chart.lock` is committed and no longer matches
`Chart.yaml`, `helm dependency build` fails with a different message ("the lock file ... is out of sync").

## The fix
Correct the `file://` path (or rename the library directory), push, refresh and sync. The dependency stays a
dependency: the shared labels and banner template are still defined once, in `notify-common`.

## In real life
Monorepos with an internal "common" library chart are everywhere, and renames, moves and a forgotten `Chart.lock`
are the usual breakages. Check chart changes with `helm dependency build && helm template` locally or in CI
before pushing, because Argo CD only reports the failure after the merge. Copying the helpers into each chart
"just to make it deploy" quietly forks the shared code.

## Commands worth remembering
```bash
argocd app get NAME                       # ComparisonError text
helm dependency build charts/notify       # same step the repo-server runs
helm template charts/notify               # render locally
argocd app manifests NAME
```

## Common mistakes
- Guessing another path without checking `ls`: the error just changes its text.
- Copying `_helpers.tpl` into the service chart and deleting the dependency.
- Fixing Git but forgetting to refresh/sync: the Application stays Unknown or OutOfSync.
