# The Defaulted Field

## What broke
One panel in Git had `refresh:` with nothing after it. YAML reads that as `null`. The `StatusBoard` CRD declares
`default: 30s` for the field, so the API server stored `refresh: 30s` on that panel. Argo CD compared Git (no
value) with the live object (`30s`) and called it a difference; syncing wrote the same thing again, so the
difference came back after every sync. `kubectl` showed three healthy panels and nobody had touched the cluster.

## Why Argo CD behaves this way
Argo CD's diff compares *desired* (Git) with *live*, after normalising both. Fields that exist only in the
live object (status, defaults, other controllers' annotations) are normally ignored, and for built-in kinds
Argo CD knows the schema and normalises defaults away. For a custom resource it only has the JSON: maps are
compared key by key, but **an array is one value**. As soon as any item of `panels` differs, the whole array
differs, and a defaulted key that only the live item has becomes visible in the diff. On Argo CD 3.6.1 a plain
omitted default (no `refresh` key at all) did *not* cause a diff in a plain array: the 3-way comparison against
the last applied state hides it. A null or blank value is different: the server rewrites it, so Git and live
can never agree. The same family of problems appears with quantities (`1000m` vs `1`), booleans or numbers
written as strings, and fields mutated by admission webhooks.

## The fix
Prefer the explicit manifest: write the value the server stores (`refresh: 30s`, or remove the empty key so
nothing claims to set it). Git then shows what really runs and there is no exception to maintain. When the value
is owned by someone else (a controller or webhook fills it in), use `ignoreDifferences` on exactly that path
(`jqPathExpressions` or `jsonPointers`), per Application or for all Applications in `argocd-cm`
(`resource.customizations.ignoreDifferences.<group>_<kind>`). `ServerSideDiff=true` (an annotation
`argocd.argoproj.io/compare-options` on the Application) lets the API server compute the result including
defaults and is a third option.

## In real life
Blank values come from Helm or Kustomize templates with an unset variable (`refresh: {{ .Values.refresh }}`),
and third-party CRDs (cert-manager, Istio, Prometheus Operator, Crossplane) are where defaulting hits first.
A permanent OutOfSync turns every sync button into noise, makes automated sync re-apply forever, and trains
people to ignore the colour that is supposed to alert them.

## Commands worth remembering
```bash
argocd app diff APP
argocd app diff APP --server-side-generate
kubectl get crd NAME -o yaml                      # look for `default:` in the schema
kubectl get KIND NAME -o yaml                     # the live, defaulted object
```

## Common mistakes
- Pressing Sync again: it re-applies the same object and the same difference returns.
- Ignoring `/spec` (or the whole array): the app is green but real edits to the board go unnoticed.
- Editing the live object by hand: the next sync puts the blank back and the server re-defaults it.
