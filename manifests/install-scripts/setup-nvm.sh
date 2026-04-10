#!/bin/bash
set -e

NODE_MAJOR=${NODE_MAJOR:-20}

export NVM_DIR="/usr/local/nvm"
mkdir -p "$NVM_DIR"

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# Load nvm and install Node.js
. "$NVM_DIR/nvm.sh"
nvm install "$NODE_MAJOR"
nvm alias default "$NODE_MAJOR"
nvm use default

# Create a stable symlink for PATH (nvm stores binaries in versioned dirs)
ln -sf "$(dirname "$(which node)")" "$NVM_DIR/current"

node --version
npm --version
