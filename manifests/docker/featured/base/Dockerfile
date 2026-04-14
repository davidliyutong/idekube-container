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
    MINICONDA_VERSION=latest \
    CODER_VERSION=4.7.0 \
    VIRTUALGL_VERSION=3.1 \
    TURBOVNC_VERSION=3.1

# Avoid prompts for time zone
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ}

# Change APT Source
RUN if [ ${USE_APT_MIRROR} != "false" ]; then \
        sed -i s@/archive.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/security.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list && \
        sed -i s@/ports.ubuntu.com/@/${APT_MIRROR}/@g /etc/apt/sources.list; \
    fi;

# built-in packages
RUN --mount=type=bind,source=manifests/install-scripts/setup-packages.sh,target=/tmp/setup-packages.sh \
    bash /tmp/setup-packages.sh

# tini to fix subreap
RUN --mount=type=bind,source=manifests/install-scripts/setup-tini.sh,target=/tmp/setup-tini.sh \
    export TINI_VERSION=${TINI_VERSION}; bash /tmp/setup-tini.sh

# Setup the websocat and ssh
RUN --mount=type=bind,source=manifests/install-scripts/setup-websocat-ssh.sh,target=/tmp/setup-websocat-ssh.sh \
    export WEBSOCAT_VERSION=${WEBSOCAT_VERSION}; bash /tmp/setup-websocat-ssh.sh

# Setup the code-server
RUN --mount=type=bind,source=manifests/install-scripts/setup-code-server.sh,target=/tmp/setup-code-server.sh \
    export CODER_VERSION=${CODER_VERSION}; bash /tmp/setup-code-server.sh

# Install Miniconda
RUN --mount=type=bind,source=manifests/install-scripts/setup-miniconda.sh,target=/tmp/setup-miniconda.sh \
    export MINICONDA_VERSION=${MINICONDA_VERSION}; bash /tmp/setup-miniconda.sh
ENV PATH=/opt/miniconda3/bin:$PATH

# Setup VGL
RUN --mount=type=bind,source=manifests/install-scripts/setup-vgl.sh,target=/tmp/setup-vgl.sh \
    bash /tmp/setup-vgl.sh
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

# Desktop
RUN --mount=type=bind,source=manifests/install-scripts/setup-desktop.sh,target=/tmp/setup-desktop.sh \
    bash /tmp/setup-desktop.sh

# Install the Chromium with ppa:xtradeb/apps
RUN --mount=type=bind,source=manifests/install-scripts/setup-chromium.sh,target=/tmp/setup-chromium.sh \
    bash /tmp/setup-chromium.sh

# Install TurboVNC and VirtualGL, must done after the desktop
RUN --mount=type=bind,source=manifests/install-scripts/setup-vnc.sh,target=/tmp/setup-vnc.sh \
    bash /tmp/setup-vnc.sh
ENV PATH=$PATH:/opt/VirtualGL/bin:/opt/TurboVNC/bin \
    VGL_DISPLAY=egl \
    VNC_THREADS=2 \
    LD_PRELOAD=/usr/lib/libdlfaker.so:/usr/lib/libvglfaker.so

# noVNC
RUN git clone --depth 1 --branch v1.5.0 https://github.com/novnc/noVNC.git /var/lib/novnc && \
    git clone --depth 1 --branch v0.12.0 https://github.com/novnc/websockify.git /var/lib/novnc/utils/websockify

# Create the IDEKube user with home and bash shell
RUN --mount=type=bind,source=manifests/install-scripts/setup-user.sh,target=/tmp/setup-user.sh \
    bash /tmp/setup-user.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

# Setup the root filesystem
COPY artifacts/docker/rootfs /
COPY artifacts/docker/featured/rootfs /
COPY frontend/dist/ /usr/share/nginx/html/

# Health check server
COPY --from=healthcheck-builder /idekube-healthcheck /usr/local/bin/idekube-healthcheck

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
