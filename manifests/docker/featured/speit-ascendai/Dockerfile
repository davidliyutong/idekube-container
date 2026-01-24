# These arguments are passed in via the docker build command
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

FROM ${REGISTRY}/${AUTHOR}/${NAME}:featured-base-${GIT_TAG}${TAG_POSTFIX} AS system

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
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# Configure Python environment
RUN . /opt/miniconda3/etc/profile.d/conda.sh && conda activate && \
    conda create -n pytorch python=3.11 -y

SHELL ["conda", "run", "-n", "pytorch", "/bin/bash", "-c"]

COPY manifests/install-scripts/setup-ascendai-env.sh /tmp/setup-ascendai-env.sh
RUN bash /tmp/setup-ascendai-env.sh && rm /tmp/setup-ascendai-env.sh

SHELL ["/bin/bash", "-c"]