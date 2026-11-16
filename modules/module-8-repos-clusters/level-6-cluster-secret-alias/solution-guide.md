# Walkthrough - Register A Second Destination

1. **See the symptom.**
   ```bash
   argocd app get boarding-pass        # Unknown ... x509: certificate signed by unknown authority
   argocd cluster list                 # staging  Failed
   ```
2. **Read the cluster Secret** (without printing the token):
   ```bash
   kubectl -n argocd get secret cluster-staging -o jsonpath='{.data.config}' | base64 -d | jq 'del(.bearerToken)'
   # {}   <- no tlsClientConfig
   ```
   The token authenticates Argo CD, but nothing tells it which CA signed the API server certificate for
   `kubernetes.default.svc.cluster.local`.
3. **Get the CA.** The ServiceAccount's token Secret carries it (the `kube-root-ca.crt` ConfigMap holds the
   same certificate):
   ```bash
   kubectl -n boarding-stg get secret argocd-deployer-token -o jsonpath='{.data.ca\.crt}'
   ```
4. **Put it into `config`.** Keep the token, add `tlsClientConfig` with `caData` (base64, as printed above):
   ```bash
   CA=$(kubectl -n boarding-stg get secret argocd-deployer-token -o jsonpath='{.data.ca\.crt}')
   cfg=$(kubectl -n argocd get secret cluster-staging -o jsonpath='{.data.config}' | base64 -d \
         | jq -c --arg ca "$CA" '. + {tlsClientConfig:{insecure:false,caData:$ca}}')
   kubectl -n argocd patch secret cluster-staging --type merge \
     -p "$(jq -nc --arg c "$cfg" '{stringData:{config:$c}}')"
   ```
5. **Refresh and verify.**
   ```bash
   argocd cluster list                 # staging  Successful
   argocd app get boarding-pass --refresh
   kubectl -n boarding-stg get deploy,pods
   ```
   The Application is automated, so it syncs as soon as Argo CD can read the destination.
