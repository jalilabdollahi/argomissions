# ferry-booking

Public booking API of the ferry company. One Deployment, one Service. During releases of the ticket
backend the gateway team's tooling reads the annotation `ferry.argomissions.io/maintenance` on this
Deployment and shows a maintenance banner; it is deliberately not part of Git.
