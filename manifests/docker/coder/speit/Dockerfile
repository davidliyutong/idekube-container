# These arguments are passed in via the docker build command
ARG BRANCH=unknown \
    REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    DOCKER_BRANCH=unknown \
    GIT_TAG=unknown \
    ARCH=amd64 \
    MACHINE=x86_64

FROM ${REGISTRY}/${AUTHOR}/${NAME}:coder-base-${GIT_TAG}-${ARCH} AS system

# Install packages
RUN apt-get update && apt-get install --fix-missing -y \
    tmate tmux \
    net-tools traceroute dnsutils iputils-ping \
    lldb build-essential gdb clang gcc gperf \
    graphviz ghdl openjdk-8-jre libncurses5-dev libreadline-dev flex \
    cmake ninja-build meson autoconf \
    flatpak \
    rsync \
    wxmaxima \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# WARNING: --security-opt seccomp=unconfined is required for maxima

# Install flatpak
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Configure Python environment
RUN . /opt/miniconda3/etc/profile.d/conda.sh && conda activate && \
    pip install -U pip && \
    pip config set global.index-url https://mirror.sjtu.edu.cn/pypi/web/simple && \
    pip install --no-cache-dir sympy numpy matplotlib scipy scikit-learn networkx pandas pydot graphviz jupyter && \
    pip install --no-cache-dir symbtools ipydex ipython && \
    pip install --no-cache-dir pycartan

## Install iverilog
COPY manifests/install-scripts/setup-iverilog.sh /tmp/setup-iverilog.sh
RUN /bin/bash /tmp/setup-iverilog.sh

## Install Digital
COPY manifests/install-scripts/setup-digital.sh /tmp/setup-digital.sh
RUN /bin/bash /tmp/setup-digital.sh
