#!/bin/bash
set -e

# Fail if $TTYD_VERSION is not set
if [ -z "$TTYD_VERSION" ]; then
    echo "TTYD_VERSION is not set"
    exit 1
fi

# Detect the architecture
arch=$(uname -m)

# Download the ttyd static binary
wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${arch}" \
    -O /usr/local/bin/ttyd
chmod +x /usr/local/bin/ttyd
