# Walkthrough — The Defaulted Field

1. **Read the diff.**
   ```bash
   argocd app get ops-statusboard          # OutOfSync right after a successful sync
   argocd app diff ops-statusboard         # one line only on the live side:  <     refresh: 30s
   ```
2. **Find where the value comes from.** Look at the panel in Git and at the CRD schema:
   ```bash
   grep -n refresh statusboard-config/deploy/statusboard.yaml
   #   refresh: 10s / refresh:   (blank) / refresh: 1m
   kubectl get crd statusboards.argomissions.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.panels.items.properties.refresh}'
   # {"default":"30s","type":"string"}
   ```
   The blank `refresh:` in the `error-budget` panel is `null`. For the API server a null with a schema default
   means "use the default", so the stored panel says `refresh: 30s`. Git says nothing, and because Argo CD
   compares a custom resource's `panels` array as one value, the panel can never match.
3. **Fix it in Git.** Say the value the server would store:
   ```bash
   cd statusboard-config
   sed -i.bak 's/^      refresh:$/      refresh: 30s/' deploy/statusboard.yaml && rm deploy/statusboard.yaml.bak
   git commit -am "Make the panel refresh explicit" && git push
   argocd app get ops-statusboard --refresh
   argocd app sync ops-statusboard
   ```
   (Deleting the blank `refresh:` line works as well.) Or keep Git as it is and ignore exactly that field:
   ```yaml
   spec:
     ignoreDifferences:
       - group: argomissions.io
         kind: StatusBoard
         jqPathExpressions:
           - .spec.panels[].refresh
   ```
4. **Verify.** `argocd app get ops-statusboard` stays Synced after a refresh. Run `check`.
