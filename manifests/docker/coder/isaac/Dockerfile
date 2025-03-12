# These arguments are passed in via the docker build command
ARG BRANCH=unknown \
    REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    DOCKER_BRANCH=unknown \
    GIT_TAG=unknown \
    PIP_MIRROR_URL="https://mirror.sjtu.edu.cn/pypi/web/simple" \
    USE_PIP_MIRROR="true"

FROM ${REGISTRY}/${AUTHOR}/${NAME}:coder-base-${GIT_TAG} AS system

# Install packages
RUN apt-get update && apt-get install --fix-missing -y \
    tmate tmux \
    rsync \
    lldb build-essential gdb clang gcc gperf cmake ninja-build meson autoconf \
    vulkan-tools \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*