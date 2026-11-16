# ticket-desk

Helpdesk front end. The base refers to the logical image `ticket-desk-web`; each overlay maps it to the
image it runs:

* `kustomize/overlays/staging` - `traefik/whoami:v1.10` (build 2.0, already validated in staging)
* `kustomize/overlays/prod` - deployed to namespace `desk`; still on the old build, `nginx:1.27-alpine`
