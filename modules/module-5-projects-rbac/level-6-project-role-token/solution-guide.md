# Walkthrough — A Token For The Pipeline

1. **Look at the project and at the placeholder.**
   ```bash
   argocd proj get settlements            # no roles
   kubectl -n settle-ci get secret argocd-pipeline-token -o jsonpath='{.data.token}' | base64 -d
   ```
2. **Create the role and give it only what a release needs.**
   ```bash
   argocd proj role create settlements deployer
   argocd proj role add-policy settlements deployer --action get  --permission allow --object '*'
   argocd proj role add-policy settlements deployer --action sync --permission allow --object '*'
   ```
   `--object` is relative to the project: `*` is stored as `settlements/*`. Passing `settlements/*` stores
   `settlements/settlements/*` (it still matches, but the policy is confusing). Check with
   `kubectl -n argocd get appproject settlements -o yaml`:
   `p, proj:settlements:deployer, applications, sync, settlements/*, allow`.
3. **Issue the token (shown once) and store it where the pipeline reads it.**
   ```bash
   TOKEN=$(argocd proj role create-token settlements deployer --token-only)
   kubectl -n settle-ci create secret generic argocd-pipeline-token --from-literal=token="$TOKEN" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
4. **Try it as the pipeline would, without your admin session.**
   ```bash
   argocd account can-i sync applications settlements/settle-api --auth-token "$TOKEN" --server localhost:9080 --plaintext   # yes
   argocd account can-i delete applications settlements/settle-api --auth-token "$TOKEN" --server localhost:9080 --plaintext # no
   ```
   Then run `check` in the game.

The same role as YAML in the AppProject (then only `create-token` is imperative):

```yaml
spec:
  roles:
  - name: deployer
    policies:
    - p, proj:settlements:deployer, applications, get, settlements/*, allow
    - p, proj:settlements:deployer, applications, sync, settlements/*, allow
```
