#!/bin/bash
# Bootstrap openclaw config in $HOME if it is missing.
#
# The image bakes a default config into /home/idekube/.openclaw at build
# time, but that directory is shadowed when /home/idekube is provided by a
# volume mount (e.g. docker-compose, PVC). Without a config the
# `openclaw gateway run` supervisor service exits with
#   "Missing config. Run `openclaw setup` or set gateway.mode=local".
#
# This hook re-runs the same non-interactive onboarding the build script
# uses, but only when no config is present, so existing user configs are
# left untouched.
set -e

IDEKUBE_USER=${USERNAME:-idekube}
IDEKUBE_HOME=$(getent passwd "$IDEKUBE_USER" | cut -d: -f6)

if [ -z "$IDEKUBE_HOME" ] || [ ! -d "$IDEKUBE_HOME" ]; then
    echo "openclaw-bootstrap: home for $IDEKUBE_USER not found, skipping"
    exit 0
fi

CONFIG_FILE="$IDEKUBE_HOME/.openclaw/openclaw.json"
if [ -f "$CONFIG_FILE" ]; then
    echo "openclaw-bootstrap: config already present at $CONFIG_FILE"
    exit 0
fi

if ! command -v su >/dev/null 2>&1; then
    echo "openclaw-bootstrap: 'su' not available, skipping"
    exit 0
fi

echo "openclaw-bootstrap: no config at $CONFIG_FILE, running onboard"
su - "$IDEKUBE_USER" -c "export PATH=/usr/local/nvm/current:\$PATH && \
  openclaw onboard --non-interactive --accept-risk --mode local \
    --auth-choice skip --skip-channels --skip-daemon --skip-health \
    --skip-search --skip-skills --skip-ui --no-install-daemon" \
    || { echo "openclaw-bootstrap: onboard failed"; exit 0; }

# Tell openclaw it is reverse-proxied under /agent. With this set, the
# Control UI HTML is mounted at /agent/ and the bundled JS derives a
# WebSocket URL that matches what nginx forwards. Without this, the UI
# tries to open ws://host/agent but openclaw responds with a 302 to
# /agent/ — and WebSocket clients cannot follow HTTP redirects.
su - "$IDEKUBE_USER" -c "export PATH=/usr/local/nvm/current:\$PATH && \
  openclaw config set gateway.controlUi.basePath '\"/agent\"' --strict-json" \
    2>/dev/null || echo "openclaw-bootstrap: failed to set basePath"

# Allow Control UI WebSocket connections from any browser origin. The
# gateway sits behind nginx (reachable at whatever host:port the user
# exposed the container at), so we cannot enumerate origins ahead of
# time. Token auth still gates access — this only relaxes the Origin
# header check that openclaw applies to WebSocket upgrades.
# (We do NOT also unset gateway.auth.token here: onboard above just
# generated a fresh per-volume token, so the build-time concern about
# static tokens doesn't apply.)
su - "$IDEKUBE_USER" -c "export PATH=/usr/local/nvm/current:\$PATH && \
  openclaw config set gateway.controlUi.allowedOrigins '[\"*\"]' --strict-json" \
    2>/dev/null || echo "openclaw-bootstrap: failed to set allowedOrigins"

# Drop the .bak files left behind by the config writes above; on a
# fresh volume there is no useful prior state in them. The gateway
# may write a fresh .bak on first start as part of its own
# meta-update — that one is openclaw's normal behavior.
rm -f "$IDEKUBE_HOME/.openclaw"/openclaw.json.bak* 2>/dev/null || true

echo "openclaw-bootstrap: done"
