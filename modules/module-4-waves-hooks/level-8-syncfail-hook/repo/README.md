# booking-portal

Customer-facing booking site.

* Before each sync the `maintenance-flag` ConfigMap raises the "read-only" banner.
* The `exit-maintenance` Job lowers it again.
