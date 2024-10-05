# These arguments are passed in via the docker build command
ARG BRANCH=unknown
ARG REGISTRY=docker.io
ARG AUTHOR=davidliyutong
ARG NAME=idekube-container
ARG DOCKER_BRANCH=unknown
ARG GIT_TAG=unknown
ARG ARCH=amd64
ARG MACHINE=x86_64

FROM ${REGISTRY}/${AUTHOR}/${NAME}:coder-base-${GIT_TAG}-${ARCH} AS system

# Install packages
RUN apt-get update && apt-get install --fix-missing -y \
    python3 python3-pip \
    git htop vim wget curl tree zsh bison\
    tmate tmux \
    unzip zstd \
    net-tools traceroute dnsutils iputils-ping \
    htop \
    lldb build-essential gdb clang gcc gperf \
    graphviz ghdl openjdk-8-jre libncurses5-dev libreadline-dev flex \
    cmake ninja-build meson autoconf \
    jq \
    openssh-client openssh-server \
    openssh-server \
    flatpak \
    rsync \
    supervisor \
    wxmaxima \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

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
