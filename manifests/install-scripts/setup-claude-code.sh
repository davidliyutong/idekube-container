#!/bin/bash
set -e

CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION:-latest}

# Load nvm
export NVM_DIR="/usr/local/nvm"
. "$NVM_DIR/nvm.sh"

if [ "${CLAUDE_CODE_VERSION}" = "latest" ]; then
    npm install -g @anthropic-ai/claude-code
else
    npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
fi

claude --version || true
