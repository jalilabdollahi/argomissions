# Tell Me When It Breaks

## What broke
Nothing in Argo CD was misbehaving: `payout-worker` failed its syncs exactly as it should, and Argo CD
recorded each failure in the Application's `operationState`. But a failed sync is only visible to someone who
opens Argo CD. With `argocd-notifications-cm` empty, nobody was told.

## Why Argo CD behaves this way
Notifications run in their own controller, `argocd-notifications-controller`, which watches Applications and
reads one ConfigMap (plus a Secret for tokens). Four pieces cooperate:

* a **service** (`service.webhook.chat-hook`): where to send (URL, headers, auth from `argocd-notifications-secret`);
* a **template** (`template.app-sync-failed`): what to send: for a webhook a method, a path and a body, rendered
  with Go templates over `.app`;
* a **trigger** (`trigger.on-sync-failed`): when to send: a boolean expression over the Application, and the
  templates to use;
* a **subscription**: which Applications want which trigger on which service, via the annotation
  `notifications.argoproj.io/subscribe.<trigger>.<service>: <recipient>` or `subscriptions:` in the ConfigMap.

A trigger fires when its condition turns true and is remembered in the annotation
`notified.notifications.argoproj.io`, so a failed state notifies once, not on every reconciliation; it is
forgotten when the condition turns false again (use `oncePer` to notify per revision). The controller needs no
restart for ConfigMap changes.

## The fix
Define the service, template and trigger, subscribe the Application, and let the next failure prove the chain.
`argocd admin notifications template notify` and `trigger run` can dry-run pieces of it from your terminal.

## In real life
The usual breakages are a URL that only resolves from a laptop, a secret reference (`$token`) with no key in
`argocd-notifications-secret`, a trigger whose `when` never becomes true, and an Application that was never
subscribed. Teams also forget that the receiver must answer 2xx quickly: slow or failing webhooks show up only
in the notifications controller log.

## Commands worth remembering
```bash
kubectl -n argocd get configmap argocd-notifications-cm -o yaml
kubectl -n argocd logs deploy/argocd-notifications-controller
argocd admin notifications trigger get
argocd admin notifications template get
kubectl -n argocd annotate application APP notifications.argoproj.io/subscribe.TRIGGER.SERVICE=""
```

## Common mistakes
- Using `localhost` or a cluster-external URL for the receiver: the controller resolves it from inside the cluster.
- Writing the trigger and template but forgetting the subscription annotation.
- Expecting a notification for a failure that happened before the configuration existed: trigger a new one.
