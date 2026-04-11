# Export the agent toolchain environment variables to interactive
# shells (bash + zsh, login + non-login). The Dockerfile sets these
# via `ENV` for the entrypoint process tree, but interactive shells
# started by `su -`, SSH, or `docker exec -u idekube` re-derive their
# env from this file (sourced by /etc/zsh/zshenv and /etc/bash.bashrc
# via the loop the Dockerfile appends to those files).

# Java — use the Debian arch-agnostic symlink so this works on both
# amd64 and arm64 without per-arch branching.
if [ -d /usr/lib/jvm/default-java ]; then
    export JAVA_HOME=/usr/lib/jvm/default-java
fi

# Playwright browsers were installed at build time into a system-wide
# path so the unprivileged idekube user can launch them even when
# /home/idekube is volume-mounted (which would shadow ~/.cache).
if [ -d /opt/ms-playwright ]; then
    export PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
fi
