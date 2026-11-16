# shiftboard

Staff rostering service.

* `crds/` - the `ShiftPolicy` CustomResourceDefinition, Argo CD Application `rota-crds`.
* `deploy/` - the service, its migrator RBAC, migration Job (PreSync hook), weekend policy and PostSync smoke test,
  Argo CD Application `shiftboard`. Synced manually on release day.
