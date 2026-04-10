#!/bin/bash
set -e

curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard

openclaw --version || true

# Bootstrap default local config so the gateway starts without manual setup.
# Run as the container user so config lands in their home directory.
IDEKUBE_USER=${USERNAME:-idekube}
IDEKUBE_HOME=$(eval echo "~$IDEKUBE_USER")

su - "$IDEKUBE_USER" -c "export PATH=/usr/local/nvm/current:\$PATH && \
  openclaw onboard --non-interactive --accept-risk --mode local \
    --auth-choice skip --skip-channels --skip-daemon --skip-health \
    --skip-search --skip-skills --skip-ui --no-install-daemon"

# Remove runtime state that should not be baked into the image.
# The gateway will regenerate these on first start.
rm -rf "$IDEKUBE_HOME/.openclaw/logs" \
       "$IDEKUBE_HOME/.openclaw/tasks" \
       "$IDEKUBE_HOME/.openclaw/update-check.json"

# Strip the generated auth token — a fresh one will be created at runtime
# or the user can configure their own.
su - "$IDEKUBE_USER" -c "export PATH=/usr/local/nvm/current:\$PATH && \
  openclaw config unset gateway.auth.token" 2>/dev/null || true
