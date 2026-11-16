# Only Prod Gets Auto-Sync

## What broke
The ApplicationSet template had no sync policy, so every generated Application was manual: the release merged to
`main` was never rolled out to production. The requirement was not "turn on automation" but "turn it on for one
environment only", and an ApplicationSet template is the same for every element.

## Why Argo CD behaves this way
`spec.template` is rendered once per parameter set; everything in it applies to all generated Applications.
To vary part of an Application per element you have three tools:

* **Template parameters.** Put a value in the element and reference it (`{{.revision}}`). Good for values, awkward for
  structure: you cannot say "include this whole block only for prod".
* **`templatePatch`** (needs `goTemplate: true`). A second template, written as a YAML string, rendered per element and
  merged over the main template as a patch. Go-template conditions decide whether a block appears at all, which is exactly
  what "automated sync only for prod" needs.
* **Generator-level `template`.** Each generator can carry its own `template` that is merged over the top-level one; use
  separate generators for groups of environments.

The generated Applications are owned by the set, so a sync policy set directly on an Application is overwritten at the next
reconcile.

## The fix
A `templatePatch` with `{{- if eq .env "prod" }}` that adds `syncPolicy.automated.prune: true`. Production now converges to
`main` on its own; dev and stage keep waiting for a human (they are still OutOfSync, which is what the QA team wants).

## In real life
Typical per-environment differences: auto-sync with self-heal in dev, manual or sync windows in prod, different
`ignoreDifferences`, extra sync options or notifications annotations for production only. Keep `templatePatch` small:
it is a string template with no schema validation at authoring time, so a broken patch shows up as an ErrorOccurred
condition on the ApplicationSet, and indentation matters (render with `argocd appset generate` first).

## Commands worth remembering
```bash
kubectl explain applicationset.spec.templatePatch
argocd appset generate lumen-appset.yaml -o yaml
argocd app get lumen-prod | grep -i 'sync policy'
kubectl -n argocd get applicationset lumen-gateway -o json | jq '.status.conditions'
```

## Common mistakes
- Putting `automated` in the top-level template: dev and stage then follow `main` too and QA's frozen rigs move.
- Editing the generated Application: it is reverted by the controller.
- Forgetting `goTemplate: true` (templatePatch needs it) or breaking the indentation of the patch.
