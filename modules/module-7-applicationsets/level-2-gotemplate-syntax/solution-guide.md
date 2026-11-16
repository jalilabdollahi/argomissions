# Walkthrough — Template Mismatch

1. **Read the status.**
   ```bash
   kubectl -n argocd get applicationset harbor -o jsonpath='{.status.conditions[0].message}'
   ```
   `failed to parse template {{path.basename}}: template: base:1: function "path" not defined`.
   The set is Degraded and no Application is generated at all.
2. **Look at the spec.** `goTemplate: true` is set, but the template uses `{{path.basename}}` and `{{path}}`,
   the placeholder syntax of the *default* engine. With Go templates the parameters are the root object (`.`),
   so a missing dot makes `path` look like a function call.
3. **Convert every placeholder** in `harbor-appset.yaml`:
   ```yaml
   template:
     metadata:
       name: '{{.path.basename}}'
     spec:
       source:
         path: '{{.path.path}}'
   ```
4. **Apply.**
   ```bash
   kubectl apply -f harbor-appset.yaml
   argocd appset get harbor           # three generated Applications, no error
   argocd app wait dock-api dock-tracker dock-notify --health
   ```
5. **Verify** each service answers `<name> v1`, then run `check` in the game.

Alternative: delete `goTemplate` and `goTemplateOptions` and keep the old placeholders. Both work; mixing the
two syntaxes never does.
