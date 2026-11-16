# Walkthrough — Config Before Code

1. **Read the failure.**
   ```bash
   argocd app get shipping-ui
   kubectl -n shipping get pods
   kubectl -n shipping describe pod | grep -A3 -i configmap
   ```
   The operation stays `Running`: `waiting for healthy state of apps/Deployment/shipping-ui`.
   The pod is in `CreateContainerConfigError`: `configmap "shipping-ui-config" not found`.
2. **Find the order Git asks for.**
   ```bash
   grep -n "sync-wave" shipping-ui/deploy/*.yaml
   ```
   The Deployment has no annotation (wave 0); the ConfigMap and the Service have wave `"1"`. Argo CD finishes
   wave 0 first and waits for the Deployment to be Healthy. It cannot be: it needs the ConfigMap from wave 1.
3. **Fix the order in Git.** The ConfigMap belongs before the workload:
   ```yaml
   # deploy/configmap.yaml
   metadata:
     name: shipping-ui-config
     annotations:
       argocd.argoproj.io/sync-wave: "-1"
   ```
   (Removing the annotation also works: inside one wave Argo CD applies ConfigMaps before Deployments.)
4. **Push, stop the stuck operation, sync.** The old operation is still `Running` (it waits for the Deployment);
   Argo CD refuses a second one until it is terminated.
   ```bash
   cd shipping-ui && git commit -am "ConfigMap before the Deployment" && git push
   argocd app terminate-op shipping-ui
   argocd app sync shipping-ui --refresh
   argocd app wait shipping-ui --health
   ```
5. **Verify.** `kubectl -n shipping run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s shipping-ui`
   answers `shipping-ui carrier=dhl`. Then run `check` in the game.
