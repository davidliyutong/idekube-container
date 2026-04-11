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

# Create the IDEKube user (must come before openclaw, which su's into it)
RUN bash /tmp/install-scripts/setup-user.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

# Install Node.js via nvm
ENV NVM_DIR=/usr/local/nvm
RUN export NODE_MAJOR=${NODE_MAJOR}; bash /tmp/install-scripts/setup-nvm.sh
ENV PATH=$NVM_DIR/current:$PATH

# Install agent CLIs (opencode + claude code + openclaw gateway)
RUN export OPENCODE_VERSION=${OPENCODE_VERSION}; bash /tmp/install-scripts/setup-opencode.sh
RUN export CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}; bash /tmp/install-scripts/setup-claude-code.sh
RUN export OPENCLAW_VERSION=${OPENCLAW_VERSION}; bash /tmp/install-scripts/setup-openclaw.sh

# Build tools, document conversion stack, headless Java, trimmed TeX Live
RUN bash /tmp/install-scripts/setup-agent-tools.sh
ENV JAVA_HOME=/usr/lib/jvm/default-java \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

# Python data/doc/automation packages and Playwright Chromium
RUN bash /tmp/install-scripts/setup-docproc.sh

# Propagate agent env to interactive shells (su -, ssh, docker exec)
RUN bash /tmp/install-scripts/setup-agent-shell-env.sh

# Setup the root filesystem (agent rootfs + shared startup scripts)
COPY artifacts/docker/agent/rootfs /
COPY artifacts/docker/startup-scripts /

# Make the openclaw runtime bootstrap hook executable
RUN chmod +x /etc/idekube/startup.bash/*.sh

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
