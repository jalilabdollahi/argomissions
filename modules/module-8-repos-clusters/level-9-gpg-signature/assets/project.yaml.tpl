apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: treasury
  namespace: argocd
spec:
  description: Treasury services - signed commits only
  sourceRepos:
  - http://gitea.gitea.svc.cluster.local:3000/platform/treasury-core.git
  destinations:
  - server: https://kubernetes.default.svc
    namespace: treasury
  clusterResourceWhitelist: []
  signatureKeys:
  - keyID: __KEYID__
