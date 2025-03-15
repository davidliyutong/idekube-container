#!/bin/bash
set -e

# Fail if $WEBSOCAT_VERSION is not set
if [ -z "$CODER_VERSION" ]; then
    echo "CODER_VERSION is not set"
    exit 1
fi

# Detect the architecture
arch=$(uname -m);
if [ "$arch" = "x86_64" ]; then arch="amd64"; fi;
if [ "$arch" = "aarch64" ]; then arch="arm64"; fi;

# Setup the code-server
wget -q "https://github.com/cdr/code-server/releases/download/v$CODER_VERSION/code-server-$CODER_VERSION-linux-$arch.tar.gz" -O "/tmp/code-server.tar.gz"

mkdir -p /usr/lib/code-server && tar -zxf /tmp/code-server.tar.gz -C /usr/lib/code-server --strip-components=1
ln -s /usr/lib/code-server/bin/code-server /usr/local/bin/code-server
rm /tmp/code-server.tar.gz