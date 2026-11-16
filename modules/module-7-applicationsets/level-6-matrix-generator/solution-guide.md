# Walkthrough — Every Service In Every Env

1. **Read the condition.**
   ```bash
   kubectl -n argocd get applicationset mesh -o jsonpath='{.status.conditions[0].message}'
   ```
   `ApplicationSet mesh contains applications with duplicate name: mailer (and 1 more)`. The set renders
   fine (`generated 4 applications` in the controller log) but then refuses to create any of them.
2. **Count.** The matrix pairs the git directories (`services/invoicer`, `services/mailer`) with the list
   (`staging`, `prod`): four parameter sets. The template names each one `{{.path.basename}}`, which gives
   `invoicer` twice and `mailer` twice. The namespace `{{.path.basename}}-{{.env}}` was already unique.
3. **Make the name unique** in `mesh-appset.yaml`:
   ```yaml
   template:
     metadata:
       name: '{{.path.basename}}-{{.env}}'
   ```
4. **Apply and watch.**
   ```bash
   kubectl apply -f mesh-appset.yaml
   argocd app list      # invoicer-staging, invoicer-prod, mailer-staging, mailer-prod
   ```
5. **Verify** each Service answers `<service> <env>` in `<service>-<env>`, then run `check` in the game.
