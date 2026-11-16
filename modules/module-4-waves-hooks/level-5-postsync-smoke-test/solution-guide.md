# Walkthrough — The Test That Fails The Sync

1. **Find the failing step.**
   ```bash
   argocd app get booking-web
   kubectl -n booking get job,pods
   kubectl -n booking logs job/booking-web-smoke-test
   ```
   The Deployment and Service are Healthy; the operation failed because the PostSync Job
   `booking-web-smoke-test` failed. Its log: `curl: (7) Failed to connect to booking-web port 8080 ...`
   (or a timeout).
2. **Compare with the Service.**
   ```bash
   kubectl -n booking get svc booking-web      # PORT(S): 80/TCP
   cat booking-web/deploy/smoke-test.yaml      # curl http://booking-web:8080/
   ```
   The Service listens on port 80 (targetPort 5678). The test calls 8080.
3. **Fix the test in Git.**
   ```bash
   sed -i 's#http://booking-web:8080/#http://booking-web/#' booking-web/deploy/smoke-test.yaml
   cd booking-web && git commit -am "smoke test: call the Service on port 80" && git push
   ```
   (Giving the Service a second port 8080 would also make the test pass, but the test is the thing that is wrong.)
4. **Sync.**
   ```bash
   argocd app sync booking-web --refresh
   argocd app wait booking-web --health
   argocd app get booking-web      # Sync OK, the Job is listed as a PostSync hook, Succeeded
   ```
5. Run `check` in the game.
