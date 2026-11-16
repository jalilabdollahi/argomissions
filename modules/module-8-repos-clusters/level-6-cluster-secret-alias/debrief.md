# Register A Second Destination

## What broke
A cluster Secret registered the `staging` destination with a bearer token but without the certificate authority
that signed the API server's certificate. Argo CD's application controller and API server therefore refused the
TLS handshake (`x509: certificate signed by unknown authority`), the cluster showed `Failed`, and the
Application targeting `name: staging` could neither compare nor sync.

## Why Argo CD behaves this way
A cluster is just a Secret in the `argocd` namespace labelled `argocd.argoproj.io/secret-type: cluster` with
`name`, `server`, optionally `namespaces`, and a `config` JSON: credentials (`bearerToken`, or a client
certificate, or an exec provider) and `tlsClientConfig` (`caData`, `serverName`, `insecure`). Argo CD identifies a
cluster by its `server` string. Verified on v3.6.1: `https://kubernetes.default.svc` (the built-in `in-cluster`)
and `https://kubernetes.default.svc.cluster.local` are two different clusters even though both are the same API
server, which is why one cluster can be registered several times with different credentials and scopes.
A destination then picks the cluster by `server` or by `name`. With no `caData`, Argo CD uses the system roots,
which do not contain the Kubernetes CA.

## The fix
Add `tlsClientConfig` with `insecure: false` and `caData` (the cluster CA in base64) to `config`, keeping the
token. The CA comes from the ServiceAccount token Secret (`ca.crt`) or from the `kube-root-ca.crt` ConfigMap.
Argo CD watches cluster Secrets, so the change is picked up without a restart.

## In real life
Multi-cluster setups live and die by these Secrets: expired tokens, a CA that was rotated, a server address that
only resolves from the laptop where the cluster was added. `argocd cluster add` creates this Secret for you (and a
`argocd-manager` ServiceAccount with cluster-admin); production teams often hand-write it with a narrower
ServiceAccount, which is what this mission imitates. A namespace-scoped ServiceAccount also needs the Secret's
`namespaces` field, otherwise Argo CD tries to list cluster-wide resources and gets `forbidden ... at the cluster
scope` (see the next missions).

## Commands worth remembering
```bash
argocd cluster list
argocd cluster get staging -o json | jq .connectionState
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
kubectl -n argocd get secret cluster-staging -o jsonpath='{.data.config}' | base64 -d | jq 'del(.bearerToken)'
```

## Common mistakes
- Setting `"insecure": true` to silence the error: it disables TLS verification for every sync to that cluster.
- Registering the server under the same address as an existing cluster and expecting a second entry: a repeated
  `server` is the same cluster.
- Pasting the wrong CA (or the PEM instead of its base64 form) and getting `unable to parse bytes as PEM block`.
