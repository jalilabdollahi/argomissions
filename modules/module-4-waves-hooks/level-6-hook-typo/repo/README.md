# ticket-desk

Helpdesk web app. Manifests live in `deploy/`.

Releases that change the ticket schema ship a `reindex-tickets` Job that must finish **before** the new
version is rolled out, so search never serves a half-built index.
