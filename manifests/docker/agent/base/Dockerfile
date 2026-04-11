ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE} AS system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai \
    APT_MIRROR="mirror.sjtu.edu.cn" \
    USE_APT_MIRROR="true" \
    TINI_VERSION=0.19.0 \
    WEBSOCAT_VERSION=1.13.0 \
    NODE_MAJOR=22 \
    OPENCODE_VERSION=latest \
    OPENCLAW_VERSION=latest \
    CLAUDE_CODE_VERSION=latest

# Avoid prompts for time zone
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ} \
    PYTHONIOENCODING=utf-8

# Copy the install scripts
COPY manifests/install-scripts/ /tmp/install-scripts/

# Change APT Source
RUN if [ ${USE_APT_MIRROR} != "false" ]; then \
        sed -i s@/archive.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/security.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/ports.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list; \
    fi;

# built-in packages (supervisor, nginx, sshd, python3, git, jq, tmux, ...)
RUN bash /tmp/install-scripts/setup-packages.sh

# tini to fix subreap
RUN export TINI_VERSION=${TINI_VERSION}; bash /tmp/install-scripts/setup-tini.sh

# Setup the websocat and ssh
RUN export WEBSOCAT_VERSION=${WEBSOCAT_VERSION}; bash /tmp/install-scripts/setup-websocat-ssh.sh

# Create the IDEKube user (must come before setup-openclaw.sh which does `su - idekube`)
RUN bash /tmp/install-scripts/setup-user.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

# Install Node.js via nvm
ENV NVM_DIR=/usr/local/nvm
RUN export NODE_MAJOR=${NODE_MAJOR}; bash /tmp/install-scripts/setup-nvm.sh
ENV PATH=$NVM_DIR/current:$PATH

# Expose nvm + agent CLIs (openclaw, claude, opencode, node, npm) and
# the rest of the agent toolchain (JAVA_HOME, PLAYWRIGHT_BROWSERS_PATH,
# ...) to interactive login shells started via `su -`, SSH, or
# `docker exec`. The image-level ENV only affects the entrypoint
# process tree; interactive shells re-derive their environment from
# these files.
#   - /etc/environment: PAM-loaded for any login session (bash, zsh, ...)
#   - /etc/zsh/zshenv:  zsh-specific, sourced unconditionally
#   - /etc/bash.bashrc: bash interactive non-login fallback
# We source ALL of /etc/profile.d/*.sh from zshenv/bashrc so any new
# script dropped in by the rootfs overlay (nvm.sh, agent-env.sh, ...)
# is picked up automatically without further Dockerfile edits.
RUN sed -i 's|^PATH="|PATH="/usr/local/nvm/current:|' /etc/environment && \
    printf '\nJAVA_HOME="/usr/lib/jvm/default-java"\nPLAYWRIGHT_BROWSERS_PATH="/opt/ms-playwright"\n' >> /etc/environment && \
    printf '\nfor f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done\n' >> /etc/zsh/zshenv && \
    printf '\nfor f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done\n' >> /etc/bash.bashrc

# Install opencode AI coding assistant
RUN export OPENCODE_VERSION=${OPENCODE_VERSION}; bash /tmp/install-scripts/setup-opencode.sh

# Install Claude Code CLI
RUN export CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}; bash /tmp/install-scripts/setup-claude-code.sh

# Install openclaw agent service
RUN export OPENCLAW_VERSION=${OPENCLAW_VERSION}; bash /tmp/install-scripts/setup-openclaw.sh

# Install system tools, document processing, Java, and a suitable
# subset of TeX Live for PDF compilation (latex-recommended +
# common fonts + xelatex for unicode/CJK). The full texlive package
# is several gigabytes and intentionally avoided.
RUN apt-get update && apt-get install --fix-missing -y \
        build-essential gcc g++ clang gdb \
        cmake ninja-build meson autoconf \
        graphviz \
        imagemagick ffmpeg tesseract-ocr \
        libreoffice \
        xvfb \
        openjdk-21-jre-headless \
        texlive-latex-recommended texlive-fonts-recommended texlive-xetex lmodern \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Use the architecture-agnostic Debian symlink so JAVA_HOME is correct
# on both amd64 and arm64 builds.
ENV JAVA_HOME=/usr/lib/jvm/default-java

# Install the Playwright browser bundle into a system-wide path so it
# is reachable by any user (idekube at runtime, root at build). The
# default location is the calling user's ~/.cache, which the volume
# mount of /home/idekube would shadow at runtime anyway.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

# Install Python data/doc/automation packages and Playwright Chromium
# (honors PLAYWRIGHT_BROWSERS_PATH set above).
RUN bash /tmp/install-scripts/setup-docproc.sh && \
    chmod -R go+rX /opt/ms-playwright

# Setup the root filesystem (agent rootfs + shared startup scripts)
COPY artifacts/docker/agent/rootfs /
COPY artifacts/docker/startup-scripts /

# Make the openclaw runtime bootstrap hook executable
RUN chmod +x /etc/idekube/startup.bash/*.sh

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
