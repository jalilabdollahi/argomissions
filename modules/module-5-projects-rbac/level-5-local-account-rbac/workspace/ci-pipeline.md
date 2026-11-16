# The CI pipeline

The shop's pipeline logs in as the local account `ci-bot` and then runs:

    argocd app sync shop-web

Credentials (stored in the pipeline's secret store):

    user:     ci-bot
    password: ci-bot-pass-123

To act as the bot without touching your own Argo CD login, give the CLI a separate config file:

    argocd --config /tmp/ci-bot.config --plaintext --server localhost:9080 login localhost:9080 --username ci-bot --password ci-bot-pass-123
    argocd --config /tmp/ci-bot.config account can-i sync applications 'shop/shop-web'
