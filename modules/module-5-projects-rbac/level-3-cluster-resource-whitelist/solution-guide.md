# Walkthrough — ClusterRole Forbidden

1. **Read the failure.**
   ```bash
   argocd app get radar-agent
   # Message: one or more synchronization tasks are not valid: resource rbac.authorization.k8s.io:ClusterRole
   #          is not permitted in project radar; resource rbac.authorization.k8s.io:ClusterRoleBinding ...
   ```
2. **Look at the project.**
   ```bash
   argocd proj get radar     # Allowed Cluster Resources: <none>
   ```
3. **Allow exactly the two kinds in the repo.**
   ```bash
   argocd proj allow-cluster-resource radar rbac.authorization.k8s.io ClusterRole
   argocd proj allow-cluster-resource radar rbac.authorization.k8s.io ClusterRoleBinding
   ```
4. **Sync again** (a sync that failed validation does not retry by itself):
   ```bash
   argocd app sync radar-agent
   argocd app wait radar-agent --health
   ```
5. **Verify.**
   ```bash
   kubectl get clusterrole,clusterrolebinding radar-node-reader
   kubectl -n radar get deploy,svc
   ```
