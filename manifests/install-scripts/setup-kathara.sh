#!/bin/bash
# Install Kathara and network analysis tools
# Converted from manifests/qemu/featured/kathara/install.yml
set -euo pipefail

NETCAP_VERSION="${NETCAP_VERSION:-v0.6.11}"

# Install common network tools (available on all architectures)
apt-get update
apt-get install -y --no-install-recommends \
    xterm \
    wireshark \
    iperf \
    iperf3 \
    netcat-traditional \
    tcpdump

# Install Kathara (PPA is amd64-only)
arch="$(uname -m)"
if [ "$arch" = "x86_64" ]; then
    add-apt-repository -y ppa:katharaframework/kathara
    apt-get update
    apt-get install -y --no-install-recommends kathara
else
    echo "Skipping Kathara install (PPA unavailable for arch: $arch)"
fi

# Install netcap (amd64 only)
arch="$(uname -m)"
if [ "$arch" = "x86_64" ]; then
    wget -qO /tmp/netcap.tar.gz \
        "https://github.com/dreadl0ck/netcap/releases/download/${NETCAP_VERSION}/netcap_${NETCAP_VERSION}_linux_amd64_libc.tar.gz"
    mkdir -p /tmp/netcap
    tar xzf /tmp/netcap.tar.gz -C /tmp/netcap --strip-components=1
    install -m 0755 /tmp/netcap/net /usr/local/bin/net
    rm -rf /tmp/netcap.tar.gz /tmp/netcap
else
    echo "Skipping netcap install (unsupported arch: $arch)"
fi

# Clone Kathara Labs
git clone --depth 1 https://github.com/KatharaFramework/Kathara-Labs.git /opt/Kathara-Labs

# Clean up
apt-get autoclean -y
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
