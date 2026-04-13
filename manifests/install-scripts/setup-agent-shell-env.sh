#!/bin/bash
set -e

# Make the agent toolchain (nvm, claude, opencode, JAVA_HOME,
# PLAYWRIGHT_BROWSERS_PATH, ...) reachable from interactive login
# shells started via `su -`, SSH, or `docker exec`. The Dockerfile's
# ENV only affects the entrypoint process tree; interactive shells
# re-derive their environment from the files touched here.
#
#   - /etc/environment: PAM-loaded for any login session (bash, zsh, ...)
#   - /etc/zsh/zshenv:  zsh-specific, sourced unconditionally
#   - /etc/bash.bashrc: bash interactive non-login fallback
#
# Both shell rc files source every /etc/profile.d/*.sh so any new
# script dropped in by the rootfs overlay (nvm.sh, agent-env.sh, ...)
# is picked up automatically without further edits here.

sed -i 's|^PATH="|PATH="/usr/local/nvm/current:|' /etc/environment
printf '\nJAVA_HOME="/usr/lib/jvm/default-java"\nPLAYWRIGHT_BROWSERS_PATH="/opt/ms-playwright"\n' >> /etc/environment

PROFILE_LOOP='\nfor f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done\n'
printf "$PROFILE_LOOP" >> /etc/zsh/zshenv
printf "$PROFILE_LOOP" >> /etc/bash.bashrc
