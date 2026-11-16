# vaultline-backups

Backup schedules for the Vaultline ledger platform. One `Backup` custom resource per schedule; the
vaultline operator (installed separately) runs them and writes the outcome to `.status`.
