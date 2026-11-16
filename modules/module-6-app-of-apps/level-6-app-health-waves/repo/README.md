# beacon-fleet

The Beacon telemetry platform, deployed with the app-of-apps pattern.

* `apps/`       - child Application manifests, synced by the root Application `beacon-root`
* `workloads/`  - Kubernetes manifests of each component

Order of bring-up: the ingest database (`beacon-db`, sync-wave 1) must be serving before the API (`beacon-api`,
sync-wave 2) is even created: on a fresh cluster the API's schema check runs once at start-up and the on-call has
been paged for it before. The database replays its write-ahead log for about half a minute before it is ready.
