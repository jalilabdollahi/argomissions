# settle-api
Settlement API of the payments platform. Deployed by Argo CD (project `settlements`).
The release pipeline lives in namespace `settle-ci` and reads its Argo CD credentials from the Secret
`argocd-pipeline-token`.
