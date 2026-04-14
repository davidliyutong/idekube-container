# syntax=docker/dockerfile:1
ARG BASE_IMAGE=ubuntu:24.04

FROM golang:1.24-alpine AS healthcheck-builder
WORKDIR /build
COPY tools/idekube-healthcheck/ .
RUN go mod download && go build -o /idekube-healthcheck .

FROM ${BASE_IMAGE} AS system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai \
    APT_MIRROR="mirror.sjtu.edu.cn" \
    USE_APT_MIRROR="true" \
    TINI_VERSION=0.19.0 \
    WEBSOCAT_VERSION=1.13.0 \
    TTYD_VERSION=1.7.7 \
    NODE_MAJOR=22 \
    OPENCODE_VERSION=latest \
    CLAUDE_CODE_VERSION=latest

# Avoid prompts for time zone
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ} \
    PYTHONIOENCODING=utf-8

# Change APT Source
RUN if [ ${USE_APT_MIRROR} != "false" ]; then \
        sed -i s@/archive.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/security.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/ports.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list; \
    fi;

# built-in packages (supervisor, nginx, sshd, python3, git, jq, tmux, ...)
RUN --mount=type=bind,source=manifests/install-scripts/setup-packages.sh,target=/tmp/setup-packages.sh \
    bash /tmp/setup-packages.sh

# tini to fix subreap
RUN --mount=type=bind,source=manifests/install-scripts/setup-tini.sh,target=/tmp/setup-tini.sh \
    export TINI_VERSION=${TINI_VERSION}; bash /tmp/setup-tini.sh

# Setup the websocat and ssh
RUN --mount=type=bind,source=manifests/install-scripts/setup-websocat-ssh.sh,target=/tmp/setup-websocat-ssh.sh \
    export WEBSOCAT_VERSION=${WEBSOCAT_VERSION}; bash /tmp/setup-websocat-ssh.sh

# Setup ttyd (web terminal)
RUN --mount=type=bind,source=manifests/install-scripts/setup-ttyd.sh,target=/tmp/setup-ttyd.sh \
    export TTYD_VERSION=${TTYD_VERSION}; bash /tmp/setup-ttyd.sh

# Create the IDEKube user (must come before openclaw, which su's into it)
RUN --mount=type=bind,source=manifests/install-scripts/setup-user.sh,target=/tmp/setup-user.sh \
    bash /tmp/setup-user.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

# Install Node.js via nvm
ENV NVM_DIR=/usr/local/nvm
RUN --mount=type=bind,source=manifests/install-scripts/setup-nvm.sh,target=/tmp/setup-nvm.sh \
    export NODE_MAJOR=${NODE_MAJOR}; bash /tmp/setup-nvm.sh
ENV PATH=$NVM_DIR/current:$PATH

# Install agent CLIs (opencode + claude code)
RUN --mount=type=bind,source=manifests/install-scripts/setup-opencode.sh,target=/tmp/setup-opencode.sh \
    export OPENCODE_VERSION=${OPENCODE_VERSION}; bash /tmp/setup-opencode.sh
RUN --mount=type=bind,source=manifests/install-scripts/setup-claude-code.sh,target=/tmp/setup-claude-code.sh \
    export CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}; bash /tmp/setup-claude-code.sh

# Build tools, document conversion stack, headless Java, trimmed TeX Live
RUN --mount=type=bind,source=manifests/install-scripts/setup-agent-tools.sh,target=/tmp/setup-agent-tools.sh \
    bash /tmp/setup-agent-tools.sh
ENV JAVA_HOME=/usr/lib/jvm/default-java \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

# Python data/doc/automation packages and Playwright Chromium
RUN --mount=type=bind,source=manifests/install-scripts/setup-docproc.sh,target=/tmp/setup-docproc.sh \
    bash /tmp/setup-docproc.sh

# Propagate agent env to interactive shells (su -, ssh, docker exec)
RUN --mount=type=bind,source=manifests/install-scripts/setup-agent-shell-env.sh,target=/tmp/setup-agent-shell-env.sh \
    bash /tmp/setup-agent-shell-env.sh

# Setup the root filesystem (common rootfs + agent overrides)
COPY artifacts/docker/rootfs /
COPY artifacts/docker/agent/rootfs /
COPY frontend/dist/ /usr/share/nginx/html/

# Health check server
COPY --from=healthcheck-builder /idekube-healthcheck /usr/local/bin/idekube-healthcheck

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
