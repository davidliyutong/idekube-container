#!/bin/bash
# ./scripts/setup-iverilog.sh <arch> <version>
# Choose an architecture
echo "Setting Up iverilog"

ARCH=$(uname -m)
echo "ARCH: $ARCH"

# Get version: prefer IVERILOG_VERSION env var, then positional arg $2, then GitHub API
if [[ -n "${IVERILOG_VERSION}" && "${IVERILOG_VERSION}" != "latest" ]]; then
    VERSION="${IVERILOG_VERSION}"
elif [[ $# -gt 1 ]]; then
    VERSION=$2
else
    VERSION=$(curl -sL https://api.github.com/repos/steveicarus/iverilog/releases/latest | jq -r ".tag_name")
    if [[ ! -n $VERSION ]]; then
        echo "Failed to get the latest version, fallback to v12_0"
        VERSION="v12_0"
    fi
fi
echo "VERSION: $VERSION"

# Download the tarball
DOWNLOAD_DESTINATION="/tmp/iverilog.tar.gz"
if [[ ! -f $DOWNLOAD_DESTINATION ]]; then
    echo "Downloading src tarball for $ARCH"
    wget https://github.com/steveicarus/iverilog/archive/refs/tags/$VERSION.tar.gz -O $DOWNLOAD_DESTINATION
else
    echo "$DOWNLOAD_DESTINATION exists, skipping download"
fi

set -e
tar -xf $DOWNLOAD_DESTINATION -C /opt
cd /opt/$(ls /opt | grep iverilog | grep -v tar.gz)
echo "Entering $(pwd)"
sh autoconf.sh
./configure
make
make check
make install
set +e