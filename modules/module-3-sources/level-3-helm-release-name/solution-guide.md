# Walkthrough - The Renamed Release

1. **See the new names.**
   ```bash
   kubectl -n fleet get svc,deploy      # fleet-tracker-api only
   grep -n Release fleet-tracker/chart/templates/*.yaml    # name: {{ .Release.Name }}-api
   ```
2. **Understand where `fleet-tracker` comes from.** Argo CD runs `helm template <Application name> ...`.
   `argocd app get fleet-tracker` -> the release name is not set, so it defaults to the Application name.
   ```bash
   helm template fleet-tracker fleet-tracker/chart | grep -n "name: .*-api"   # fleet-tracker-api
   helm template tracker fleet-tracker/chart | grep -n "name: .*-api"         # tracker-api
   ```
3. **Set the release name.**
   ```bash
   argocd app set fleet-tracker --release-name tracker
   ```
   (UI: App Details, Helm section, "Release name".) Automated sync with prune recreates `tracker-api`
   and removes the `fleet-tracker-api` objects. Watch it with `argocd app wait fleet-tracker --health`.
   Alternative: change the chart templates in Git to the fixed name `tracker-api`.
4. **Verify.**
   ```bash
   kubectl -n fleet get svc,deploy      # tracker-api only
   kubectl -n fleet run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s tracker-api
   ```
   Then run `check` in the game.
