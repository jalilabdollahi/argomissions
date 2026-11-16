# Test Fixtures In Production

## What broke
Nothing was misconfigured in Kubernetes. The `collector` Application recursed into `deploy/` and `deploy/tests/`
held CI fixtures (a load generator and a fake upstream). Argo CD rendered them like any other manifest and the
automated sync deployed them, so test traffic generators were running next to the production collector.

## Why Argo CD behaves this way
A directory source renders every `*.yaml`, `*.yml` and `*.json` file under its path (all subfolders with
`recurse: true`). Argo CD has no idea which files are "tests"; it deploys what the source gives it. You shape
the source with two globs on `spec.source.directory`: `exclude` removes matching files, `include` keeps only
matching files. Patterns are matched against the file path relative to the source path, so `tests/*` matches
`deploy/tests/fixture-loadgen.yaml`, while the bare word `tests` matches no file at all and changes nothing.
Because `prune: true` was on, once the fixtures stop being rendered Argo CD deletes them from the cluster.

## The fix
`argocd app set collector --directory-exclude 'tests/*'` (or `include: 'collector*.yaml'`). The fixtures stay in
Git for CI, Git stays the single source of truth, and the junk objects are pruned automatically.

## In real life
Repos that serve two purposes are common: manifests next to `kind` fixtures, example values, `*.bak` copies,
`kustomization` experiments. A recursive Application that quietly deploys `examples/` has caused real incidents
(a sample Ingress claiming a production hostname is a classic). Prefer a layout where deployable files and
fixtures live in separate trees, and use `exclude` as a safety net rather than as the design.

## Commands worth remembering
```bash
argocd app set NAME --directory-recurse
argocd app set NAME --directory-exclude 'tests/*'
argocd app set NAME --directory-include '*.yaml'
argocd app manifests NAME            # exactly what is rendered
argocd app get NAME --refresh
```

## Common mistakes
- Deleting the fixtures from Git: production is clean, but CI is broken and the real cause (the Application
  deploys whatever it finds) is still there for the next folder.
- `kubectl delete` on the junk pods: Git still declares them, so the Application is OutOfSync.
- Writing a glob that matches nothing (`tests`): the Application renders exactly what it did before.
