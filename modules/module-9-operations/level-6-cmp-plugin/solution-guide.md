# Walkthrough — Bring Your Own Tool

1. **See what is wrong.**
   ```bash
   argocd app get label-printer                 # Synced, Healthy, no resources listed
   argocd app manifests label-printer           # prints nothing
   argocd app get label-printer -o json | jq '.status.sourceType'     # "Directory"
   ls label-printer/deploy                      # app.conf and nothing a plain directory app can render
   ```
   Argo CD treated `deploy/` as a plain directory of YAML. There is no YAML in it, so there is nothing to
   deploy and nothing to be out of sync with.
2. **Look at the plugin.**
   ```bash
   kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server      # 2/2: the sidecar is running
   kubectl -n argocd logs deploy/argocd-repo-server -c kv-render-cmp            # serving on .../kv-render.sock
   kubectl -n argocd get configmap kv-render-plugin -o jsonpath='{.data.plugin\.yaml}'
   ```
   The sidecar is healthy. Its `discover.find.glob` is `**/app.config`, but the file in the repo is `app.conf`,
   so the plugin answers "not my repository" and Argo CD falls back to the directory renderer.
   (Setting `spec.source.plugin.name: kv-render` on the Application does not help: it then fails with
   `could not find cmp-server plugin with name "kv-render" supporting the given repository`.)
3. **Fix the discover rule** (edit the ConfigMap; `**/*.conf` works too):
   ```bash
   kubectl -n argocd edit configmap kv-render-plugin      # glob: "**/app.conf"
   ```
4. **Restart the sidecar.** plugin.yaml is read once, at start-up:
   ```bash
   kubectl -n argocd rollout restart deploy/argocd-repo-server
   kubectl -n argocd rollout status deploy/argocd-repo-server
   ```
5. **Refresh and verify.**
   ```bash
   argocd app get label-printer --hard-refresh      # source type Plugin, Deployment + Service appear
   kubectl -n labels-print get pods
   ```
   Automated sync creates the objects. Then run `check`.
