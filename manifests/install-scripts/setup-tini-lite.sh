#!/bin/bash
set -e

# Fail if $TINI_VERSION is not set
if [ -z "$TINI_VERSION" ]; then
    echo "TINI_VERSION is not set"
    exit 1
fi

# Install build-essential and cmake
apt-get update 
apt-get install -y  --no-install-recommends build-essential cmake

# Download and build tini
wget -q "https://github.com/krallin/tini/archive/v$TINI_VERSION.tar.gz" -O "v$TINI_VERSION.tar.gz"
tar zxf "v$TINI_VERSION.tar.gz"
export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37";
cd "tini-$TINI_VERSION" && cmake . && make && make install && cd ..; 
rm -r "tini-$TINI_VERSION" "v$TINI_VERSION.tar.gz"

# Cleanup
apt-get remove -y build-essential cmake
apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*