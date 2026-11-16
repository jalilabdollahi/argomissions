# tallyline

Metering pipeline: `ingest/` (collectors), `rollup/` (aggregation), `gateway/` (read API). One Argo CD
Application per folder, each in its own namespace `tallyline-<folder>`.
