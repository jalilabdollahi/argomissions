# Walkthrough — Two Owners, One ConfigMap

1. **See the warning.**
   ```bash
   argocd app get promo-banner
   ```
   `SharedResourceWarning: ConfigMap/feature-flags is part of applications argocd/promo-banner and cart-service`.
2. **See who owns the live object and what is in it.**
   ```bash
   kubectl -n storefront get cm feature-flags -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'
   # cart-service:/ConfigMap:storefront/feature-flags
   kubectl -n storefront get cm feature-flags -o jsonpath='{.data}'      # only checkout_v2
   grep -rn feature-flags storefront-apps/                               # cart/ and promo/ both define it
   ```
3. **Choose one owner** (either is fine) and give it the complete content. Here `cart-service` keeps it:
   ```bash
   cd storefront-apps
   git rm promo/feature-flags.yaml
   echo '  promo_banner: "on"' >> cart/feature-flags.yaml
   git commit -am "feature-flags: single owner (cart-service)" && git push
   ```
   Dropping the file from `promo/` without merging its key would silently lose `promo_banner`.
4. **Refresh and check.**
   ```bash
   argocd app get cart-service --refresh
   argocd app get promo-banner --refresh
   kubectl -n storefront get cm feature-flags -o jsonpath='{.data}'      # both flags
   ```
   Both turn Synced, the warning disappears. Then run `check` in the game.

Not a fix: adding `FailOnSharedResource=true` to the Applications. It makes the second app's syncs fail instead of
warning, and Git still declares the object twice.
