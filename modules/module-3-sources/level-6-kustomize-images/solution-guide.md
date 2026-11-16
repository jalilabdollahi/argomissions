# Walkthrough - Promote Without Editing YAML

1. **See the overlays.**
   ```bash
   kubectl kustomize ticket-desk/kustomize/overlays/staging | grep image:   # traefik/whoami:v1.10
   kubectl kustomize ticket-desk/kustomize/overlays/prod    | grep image:   # nginx:1.27-alpine
   ```
2. **Override the image on the Application.**
   ```bash
   argocd app set ticket-desk --kustomize-image ticket-desk-web=traefik/whoami:v1.10
   argocd app diff ticket-desk       # only the image line changes
   ```
   (UI: App Details, Kustomize, Images. YAML: `spec.source.kustomize.images: ["ticket-desk-web=traefik/whoami:v1.10"]`.)
3. **Sync and wait.**
   ```bash
   argocd app sync ticket-desk
   argocd app wait ticket-desk --health
   ```
4. **Verify.**
   ```bash
   kubectl -n desk get deploy ticket-desk -o jsonpath='{.spec.template.spec.containers[0].image}'
   kubectl -n desk run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s ticket-desk
   ```
   Then run `check` in the game.

Equally valid: copy the staging image mapping into `kustomize/overlays/prod/kustomization.yaml`, commit, push, sync.
Not valid: `kubectl set image` - the Application becomes OutOfSync and a sync (or self-heal) reverts it.
