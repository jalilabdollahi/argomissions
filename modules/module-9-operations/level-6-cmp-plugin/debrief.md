# Bring Your Own Tool

## What broke
The `kv-render` plugin was installed and running, but its `discover` rule looked for `app.config` while the
repo holds `app.conf`. The plugin therefore never claimed the directory. Argo CD quietly fell back to the
built-in directory renderer, found no YAML, and reported an Application that was Synced, Healthy and empty.

## Why Argo CD behaves this way
A config management plugin (CMP) is a sidecar container of `argocd-repo-server` that runs the
`argocd-cmp-server` binary next to your own tooling image. It registers a unix socket in a shared volume and
reads its definition, `plugin.yaml`, once at start-up. For every Application the repo-server asks the sidecars
in turn:

* `discover` (`find.glob`, `find.command`, `find.fileName`) answers "can I render this directory?".
* the first plugin that says yes runs its `generate` command in a copy of the directory; whatever it prints
  to stdout must be Kubernetes YAML.
* if nobody matches, Argo CD uses its built-in detection: Helm, Kustomize, or plain directory.

Setting `spec.source.plugin.name` selects a plugin explicitly, but on Argo CD 3.6.1 a configured discover rule
is still evaluated: a mismatch ends in `could not find cmp-server plugin with name "kv-render" supporting the
given repository`. The Application's `status.sourceType` (`Plugin` / `Directory` / `Helm` / `Kustomize`) tells
you who rendered it.

## The fix
Correct `discover.find.glob` in the ConfigMap that holds `plugin.yaml`, then restart the repo-server so the
sidecar reloads it, then refresh the Application.

## In real life
CMPs are how teams run Jsonnet, cue, kustomize-with-helm, helmfile or in-house generators. The common
failures are exactly these: a discover rule that is too narrow, a sidecar that was never restarted after a
config change, a plugin image without the tools `generate` calls, or a `generate` that prints to stderr or
nothing. Remember the plugin runs inside the repo-server pod: it is part of your Argo CD's supply chain and
should be reviewed like code.

## Commands worth remembering
```bash
argocd app get APP -o json | jq '.status.sourceType'
argocd app manifests APP
kubectl -n argocd logs deploy/argocd-repo-server -c <plugin-sidecar>
kubectl -n argocd rollout restart deploy/argocd-repo-server
argocd app get APP --hard-refresh
```

## Common mistakes
- Committing hand-written manifests next to the config file: it "works", but the tool you built is bypassed.
- Editing the plugin ConfigMap and forgetting the restart: the sidecar keeps serving the old definition.
- Adding `plugin.name` to the Application hoping it overrides discovery.

## Argo CD 2.x vs 3.x
Plugins configured through `configManagementPlugins` in `argocd-cm` (the 2.x style) were removed in 2.8: only
sidecar plugins exist. In 3.x the sidecar plugin is the single supported mechanism.
