# Walkthrough — CI Cannot Sync

1. **Reproduce as the bot** (own config file, so the admin login of the game is untouched):
   ```bash
   argocd --config /tmp/ci-bot.config --plaintext --server localhost:9080 login localhost:9080 --username ci-bot --password ci-bot-pass-123
   argocd --config /tmp/ci-bot.config account can-i sync applications 'shop/shop-web'    # no
   ```
2. **Find the layers.** The account is declared in `argocd-cm` (`accounts.ci-bot: apiKey, login`), which only
   creates the identity. Permissions come from `argocd-rbac-cm`:
   ```bash
   kubectl -n argocd get cm argocd-rbac-cm -o yaml      # data: {}
   ```
3. **Write the least-privilege policy.**
   ```bash
   kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.csv":"p, role:shop-deployer, applications, get, shop/*, allow\np, role:shop-deployer, applications, sync, shop/*, allow\ng, ci-bot, role:shop-deployer\n"}}'
   ```
   (or `kubectl -n argocd edit cm argocd-rbac-cm`).
4. **Verify as the bot.**
   ```bash
   argocd --config /tmp/ci-bot.config account can-i sync applications 'shop/shop-web'    # yes
   argocd --config /tmp/ci-bot.config account can-i get  applications 'shop/shop-web'    # yes
   argocd --config /tmp/ci-bot.config account can-i sync applications 'people/hr-portal' # no
   argocd --config /tmp/ci-bot.config account can-i delete applications 'shop/shop-web'  # no
   ```
