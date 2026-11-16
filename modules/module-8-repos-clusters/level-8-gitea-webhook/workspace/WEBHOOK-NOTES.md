# catalog-api push notifications - SCM team notes

* Gitea hook on `platform/catalog-api`: type Gitea, content type `application/json`, event `push`,
  target `http://argocd-server.argocd.svc.cluster.local/api/webhook`.
* Its shared secret is the one stored in `argocd-secret` (namespace `argocd`), key `webhook.gitea.secret`.
  Gitea never shows a hook's secret again after it is saved; Argo CD's side is the reference.
* Gitea Web UI: repo -> Settings -> Webhooks -> the hook -> "Recent Deliveries".
