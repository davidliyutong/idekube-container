#!/bin/bash
set -e

# Fail if $WEBSOCAT_VERSION is not set
if [ -z "$WEBSOCAT_VERSION" ]; then
    echo "WEBSOCAT_VERSION is not set"
    exit 1
fi

# Detect the architecture
arch=$(uname -m);
if [ "$arch" = "arm64" ]; then arch="aarch64"; fi;

# Setup the websocat and ssh
wget -q "https://github.com/vi/websocat/releases/download/v$WEBSOCAT_VERSION/websocat.$arch-unknown-linux-musl" -O "/usr/local/bin/websocat"
chmod +x /usr/local/bin/websocat

# Setup the sshd
mkdir -p /run/sshd
if ! grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
fi