# Walkthrough — Tell Me When It Breaks

1. **Look at the situation.**
   ```bash
   argocd app get payout-worker              # Sync failed: Service "payout-worker" is invalid ...
   kubectl -n argocd get configmap argocd-notifications-cm -o yaml     # nothing configured
   kubectl -n ops-hooks logs deploy/chat-hook                           # no notifications yet
   ```
2. **Add the service, the template and the trigger** to `argocd-notifications-cm`:
   ```bash
   kubectl -n argocd patch configmap argocd-notifications-cm --type merge -p '{"data":{
     "service.webhook.chat-hook": "url: http://chat-hook.ops-hooks.svc.cluster.local\nheaders:\n- name: Content-Type\n  value: application/json\n",
     "template.app-sync-failed": "webhook:\n  chat-hook:\n    method: POST\n    path: /hooks/deploys\n    body: |\n      {\"app\": \"{{.app.metadata.name}}\", \"phase\": \"{{.app.status.operationState.phase}}\"}\n",
     "trigger.on-sync-failed": "- when: app.status.operationState.phase in ['Error', 'Failed']\n  send: [app-sync-failed]\n"}}'
   ```
   (or `kubectl -n argocd edit configmap argocd-notifications-cm`). The URL is the in-cluster DNS name:
   the controller runs inside the cluster, so `localhost` would be the controller pod itself.
3. **Subscribe the Application** to the trigger and the service:
   ```bash
   kubectl -n argocd annotate application payout-worker \
     'notifications.argoproj.io/subscribe.on-sync-failed.chat-hook='
   ```
   (The value is the recipient; a webhook service needs none, so it is empty.)
4. **Make the failure happen again** — the controller sends on the next evaluation of a failed state:
   ```bash
   argocd app sync payout-worker       # fails again
   kubectl -n ops-hooks logs deploy/chat-hook
   # ... POST /hooks/deploys 200 body={"app": "payout-worker", "phase": "Failed"}
   ```
   If nothing arrives, check `kubectl -n argocd logs deploy/argocd-notifications-controller`.
5. Run `check`.
