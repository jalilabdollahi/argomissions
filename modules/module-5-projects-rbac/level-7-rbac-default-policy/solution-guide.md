# Walkthrough — Everyone Is Admin

1. **Reproduce the problem as bob** (separate config file, so your admin session is kept):
   ```bash
   argocd login localhost:9080 --plaintext --username bob --password bob-pw-4821 --config /tmp/bob-cli
   argocd account can-i delete applications '*/*' --config /tmp/bob-cli     # yes - that is the bug
   ```
2. **Read the RBAC configuration.**
   ```bash
   kubectl -n argocd get cm argocd-rbac-cm -o yaml      # policy.default: role:admin  # TODO remove after the demo
   ```
   `policy.default` is the role granted to every authenticated user who has no matching policy.
3. **Lock the default and keep alice an administrator.** Lowering the default alone would also demote alice:
   ```bash
   kubectl -n argocd patch cm argocd-rbac-cm --type merge -p '{"data":{
     "policy.default":"role:readonly",
     "policy.csv":"g, alice, role:admin\n"}}'
   ```
   (UI/YAML equivalent: edit the ConfigMap so `data` contains `policy.default: role:readonly` and
   `policy.csv: "g, alice, role:admin"`.) No restart is needed, Argo CD reloads the ConfigMap within seconds.
4. **Verify both identities.**
   ```bash
   argocd account can-i delete applications '*/*' --config /tmp/bob-cli     # no
   argocd account can-i get applications '*/*'    --config /tmp/bob-cli     # yes
   argocd login localhost:9080 --plaintext --username alice --password alice-pw-4821 --config /tmp/alice-cli
   argocd account can-i delete applications '*/*' --config /tmp/alice-cli   # yes
   ```
   Then run `check` in the game.
