# meterhub-gitops

One root Application per environment (`meterhub-env-staging`, `meterhub-env-prod`), each pointing at its folder:

* `envs/staging/` - child Applications of staging
* `envs/prod/`    - child Applications of production

Policy: staging follows `main` of meterhub-service; production runs released tags only.
