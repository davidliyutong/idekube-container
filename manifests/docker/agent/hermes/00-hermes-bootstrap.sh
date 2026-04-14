#!/bin/bash
# Bootstrap hermes config in $HOME if it is missing.
#
# The image bakes a default config into /home/idekube/.hermes at build
# time, but that directory is shadowed when /home/idekube is provided by a
# volume mount (e.g. docker-compose, PVC). Without a config the hermes
# gateway and webui cannot start properly.
#
# This hook recreates the config structure and generates a fresh
# API_SERVER_KEY so the embedded API server is secured on every new
# volume.
set -e

IDEKUBE_USER=${USERNAME:-idekube}
IDEKUBE_HOME=$(getent passwd "$IDEKUBE_USER" | cut -d: -f6)

if [ -z "$IDEKUBE_HOME" ] || [ ! -d "$IDEKUBE_HOME" ]; then
    echo "hermes-bootstrap: home for $IDEKUBE_USER not found, skipping"
    exit 0
fi

CONFIG_FILE="$IDEKUBE_HOME/.hermes/config.yaml"

if [ -f "$CONFIG_FILE" ]; then
    echo "hermes-bootstrap: config already present at $CONFIG_FILE"
else
    echo "hermes-bootstrap: no config at $CONFIG_FILE, creating defaults"

    # Create required directory structure
    su - "$IDEKUBE_USER" -c "mkdir -p \
        $IDEKUBE_HOME/.hermes/cron \
        $IDEKUBE_HOME/.hermes/sessions \
        $IDEKUBE_HOME/.hermes/logs \
        $IDEKUBE_HOME/.hermes/memories \
        $IDEKUBE_HOME/.hermes/skills \
        $IDEKUBE_HOME/.hermes/pairing \
        $IDEKUBE_HOME/.hermes/hooks \
        $IDEKUBE_HOME/.hermes/image_cache \
        $IDEKUBE_HOME/.hermes/audio_cache \
        $IDEKUBE_HOME/.hermes/whatsapp/session \
        $IDEKUBE_HOME/.hermes/webui"

    # Copy default config from the template baked into the image
    TEMPLATE="/opt/hermes/cli-config.yaml.example"
    if [ -f "$TEMPLATE" ]; then
        cp "$TEMPLATE" "$CONFIG_FILE"
        chown "$IDEKUBE_USER:$IDEKUBE_USER" "$CONFIG_FILE"
    else
        echo "hermes-bootstrap: template not found at $TEMPLATE"
    fi
fi

# Ensure .env exists with API_SERVER_KEY
ENV_FILE="$IDEKUBE_HOME/.hermes/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "hermes-bootstrap: creating $ENV_FILE with fresh API_SERVER_KEY"
    API_KEY=$(openssl rand -hex 16)
    cat > "$ENV_FILE" <<EOF
API_SERVER_KEY=${API_KEY}
API_SERVER_HOST=127.0.0.1
API_SERVER_PORT=8642
EOF
    chown "$IDEKUBE_USER:$IDEKUBE_USER" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
elif ! grep -q "^API_SERVER_KEY=" "$ENV_FILE" 2>/dev/null; then
    echo "hermes-bootstrap: adding API_SERVER_KEY to existing $ENV_FILE"
    API_KEY=$(openssl rand -hex 16)
    echo "API_SERVER_KEY=${API_KEY}" >> "$ENV_FILE"
fi

# Ensure hermes is reachable from user's ~/.local/bin
mkdir -p "$IDEKUBE_HOME/.local/bin"
if [ ! -L "$IDEKUBE_HOME/.local/bin/hermes" ] && [ ! -f "$IDEKUBE_HOME/.local/bin/hermes" ]; then
    ln -sf /usr/local/bin/hermes "$IDEKUBE_HOME/.local/bin/hermes"
    chown -h "$IDEKUBE_USER:$IDEKUBE_USER" "$IDEKUBE_HOME/.local/bin/hermes"
fi

echo "hermes-bootstrap: done"
