# Walkthrough — Remove The Old Last

1. **Look before you sync.**
   ```bash
   argocd app diff chat-relay          # new relay-gateway objects to create, relay objects to prune
   cat chat-relay/deploy/handover-check.yaml
   ```
   `handover-check` is a Sync hook in wave 1: it runs after wave 0 (the new Deployment and Service, healthy) and prints
   whether the old and the new Service answer.
2. **Understand the default.** Objects that are no longer in Git are pruned in their own wave (wave 0 here), so the
   old Service is deleted while the new Deployment is still starting. By the time wave 1 runs, only the new one is left.
3. **Postpone the pruning.**
   ```bash
   argocd app set chat-relay --sync-option CreateNamespace=true --sync-option PruneLast=true
   ```
   (`argocd app set --sync-option` replaces the list, so repeat the existing option.)
4. **Sync with pruning.**
   ```bash
   argocd app sync chat-relay --prune
   argocd app wait chat-relay --health
   ```
5. **Verify the evidence.**
   ```bash
   kubectl -n chat logs job/handover-check
   # handover: old Service relay=up, new Service relay-gateway=up
   kubectl -n chat get svc,deploy        # only relay-gateway remains
   ```
