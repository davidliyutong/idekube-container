#!/bin/bash
# ./scripts/setup-iverilog.sh <arch> <version>
# Choose an architecture
echo "Setting Up iverilog"

ARCH=$(uname -m)
echo "ARCH: $ARCH"

# Download the code-server
if [[ $# -gt 1 ]]; then
    VERSION=$2
else
    VERSION=""
fi
if [[ ! -n $VERSION ]]; then
    VERSION=$(curl -sL https://api.github.com/repos/steveicarus/iverilog/releases/latest | jq -r ".tag_name")
fi
echo "VERSION: $VERSION"

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