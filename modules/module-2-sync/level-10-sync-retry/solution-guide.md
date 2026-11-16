# Walkthrough — Flaky First Contact

1. **Read the failure.**
   ```bash
   argocd app get sensor-hub
   ```
   The SensorProfile is `OutOfSync` with *Make sure the "SensorProfile" CRD is installed on the destination cluster*;
   the Deployment and Service are `Missing` too, because a sync whose tasks are not valid applies nothing.
2. **Find the missing piece.**
   ```bash
   kubectl get crd | grep argomissions            # nothing yet
   kubectl -n iot-bootstrap get job,pod           # install-sensor-crd is still waiting
   ```
   The platform bootstrap installs the CRD later. The Git repo is right; the order of events is not under our control.
3. **Look at the retry policy.**
   ```bash
   kubectl -n argocd get application sensor-hub -o jsonpath='{.spec.syncPolicy}'
   ```
   `retry: limit 2, backoff 5s x2`: two attempts within ~15 seconds, then the operation is `Failed` and stays that way
   until something starts a new sync (a new commit, or a human).
4. **Make the policy patient.**
   ```bash
   argocd app set sensor-hub --sync-retry-limit 8 --sync-retry-backoff-duration 10s \
     --sync-retry-backoff-factor 2 --sync-retry-backoff-max-duration 60s
   argocd app sync sensor-hub          # starts a new operation, which carries the new retry policy
   ```
   Waits: 10s, 20s, 40s, 60s, 60s, 60s, 60s, 60s, about six minutes in total. (`limit: -1` retries forever.)
5. **Verify.**
   ```bash
   argocd app wait sensor-hub --health
   kubectl -n iot-edge get sensorprofile,deploy,svc
   ```
   Then run `check` in the game.
