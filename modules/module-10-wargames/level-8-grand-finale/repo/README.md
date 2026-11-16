# meridian-platform

Transit signage platform. The root Application `meridian-root` reads `bootstrap/` (AppProjects, the `meridian-core`
Application and the `meridian-edge` ApplicationSet that creates one edge Application per district).
`core/` and `edge/` are the workloads. Core has a PostSync smoke test.
