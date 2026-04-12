# syntax=docker/dockerfile:1
ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE} AS system

# These arguments are passed in via the docker build command
ARG TZ=Asia/Shanghai \
    WEBSOCAT_VERSION=1.13.0 \
    APT_MIRROR="mirror.sjtu.edu.cn" \
    USE_APT_MIRROR="false" \
    TINI_VERSION=0.19.0 \
    MINICONDA_VERSION=latest

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

# Install Miniconda
RUN --mount=type=bind,source=manifests/install-scripts/setup-miniconda.sh,target=/tmp/setup-miniconda.sh \
    export MINICONDA_VERSION=${MINICONDA_VERSION}; bash /tmp/setup-miniconda.sh
ENV PATH=/opt/miniconda3/bin:$PATH

# Install Jupyter
RUN python3 -m pip install --no-cache-dir jupyterlab \
    jupyterlab-git jupyterlab-drawio jupyterlab-language-pack-zh-CN

RUN mkdir -p /usr/local/share/jupyter/lab/settings && \
    echo '{"@jupyterlab/apputils-extension:notification":{"fetchNews":"false"},"@jupyterlab/apputils-extension:announcements":{"checkForUpdates":false}}' > /usr/local/share/jupyter/lab/settings/overrides.json

# Create the IDEKube user with home and bash shell
RUN --mount=type=bind,source=manifests/install-scripts/setup-user.sh,target=/tmp/setup-user.sh \
    bash /tmp/setup-user.sh
ENV SHELL=/bin/bash \
    USERNAME=idekube \
    USERID=1000

# Setup the root filesystem
COPY artifacts/docker/jupyter/rootfs /
COPY artifacts/docker/startup-scripts /
COPY frontend/dist/ /usr/share/nginx/html/

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
