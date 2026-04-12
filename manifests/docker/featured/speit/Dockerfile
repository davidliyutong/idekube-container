# syntax=docker/dockerfile:1
# These arguments are passed in via the docker build command
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

FROM ${REGISTRY}/${AUTHOR}/${NAME}:featured-base-${GIT_TAG}${TAG_POSTFIX} AS system

ARG PIP_MIRROR_URL="https://mirror.sjtu.edu.cn/pypi/web/simple" \
    USE_PIP_MIRROR="true" \
    IVERILOG_VERSION=latest \
    DIGITAL_VERSION=latest

# Install packages
RUN apt-get update && apt-get install --fix-missing -y \
    tmate \
    net-tools traceroute dnsutils iputils-ping \
    lldb build-essential gdb clang gcc gperf \
    graphviz ghdl openjdk-8-jre libncurses5-dev libreadline-dev flex \
    cmake ninja-build meson autoconf \
    wxmaxima \
    && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Configure Python Mirror
RUN if [ ${USE_PIP_MIRROR} != "false" ]; then \
        pip config set global.index-url ${PIP_MIRROR_URL}; \
    fi;
# Configure Python environment
RUN --mount=type=bind,source=manifests/install-scripts/setup-speit-pip.sh,target=/tmp/setup-speit-pip.sh \
    . /opt/miniconda3/etc/profile.d/conda.sh && conda activate && \
    bash /tmp/setup-speit-pip.sh

## Install iverilog
RUN --mount=type=bind,source=manifests/install-scripts/setup-iverilog.sh,target=/tmp/setup-iverilog.sh \
    export IVERILOG_VERSION=${IVERILOG_VERSION}; /bin/bash /tmp/setup-iverilog.sh

## Install Digital
RUN --mount=type=bind,source=manifests/install-scripts/setup-digital.sh,target=/tmp/setup-digital.sh \
    export DIGITAL_VERSION=${DIGITAL_VERSION}; /bin/bash /tmp/setup-digital.sh
