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

# Make the nvm-installed CLIs (openclaw, claude, opencode, node, npm)
# available to interactive login shells started via `su -`, SSH, or
# `docker exec`. The image-level ENV PATH only affects the entrypoint
# process tree; interactive shells re-derive PATH from these files.
#   - /etc/environment: PAM-loaded for any login session (bash, zsh, ...)
#   - /etc/zsh/zshenv:  zsh-specific, sourced unconditionally
#   - /etc/bash.bashrc: bash interactive non-login fallback
RUN sed -i 's|^PATH="|PATH="/usr/local/nvm/current:|' /etc/environment && \
    echo '. /etc/profile.d/nvm.sh' >> /etc/zsh/zshenv && \
    echo '. /etc/profile.d/nvm.sh' >> /etc/bash.bashrc

# Install opencode AI coding assistant
RUN export OPENCODE_VERSION=${OPENCODE_VERSION}; bash /tmp/install-scripts/setup-opencode.sh

# Install Claude Code CLI
RUN export CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}; bash /tmp/install-scripts/setup-claude-code.sh

# Install openclaw agent service
RUN export OPENCLAW_VERSION=${OPENCLAW_VERSION}; bash /tmp/install-scripts/setup-openclaw.sh

# Install system tools, document processing, and Java
RUN apt-get update && apt-get install --fix-missing -y \
        build-essential gcc g++ clang gdb \
        cmake ninja-build meson autoconf \
        graphviz \
        imagemagick ffmpeg tesseract-ocr \
        libreoffice \
        xvfb \
        openjdk-21-jre-headless \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Install Python data/doc/automation packages and Playwright
RUN bash /tmp/install-scripts/setup-docproc.sh

# Setup the root filesystem (agent rootfs + shared startup scripts)
COPY artifacts/docker/agent/rootfs /
COPY artifacts/docker/startup-scripts /

# Make the openclaw runtime bootstrap hook executable
RUN chmod +x /etc/idekube/startup.bash/*.sh

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
