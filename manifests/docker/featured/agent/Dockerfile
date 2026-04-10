# These arguments are passed in via the docker build command
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

FROM ${REGISTRY}/${AUTHOR}/${NAME}:featured-base-${GIT_TAG}${TAG_POSTFIX} AS system

ENV PYTHONIOENCODING=utf-8
ARG NODE_MAJOR=22 \
    OPENCODE_VERSION=latest \
    OPENCLAW_VERSION=latest \
    CLAUDE_CODE_VERSION=latest

# Copy the install scripts
COPY manifests/install-scripts/ /tmp/install-scripts/

# Install Node.js via nvm
ENV NVM_DIR=/usr/local/nvm
RUN export NODE_MAJOR=${NODE_MAJOR}; bash /tmp/install-scripts/setup-nvm.sh
ENV PATH=$NVM_DIR/current:$PATH

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

# Copy the agent rootfs (includes openclaw supervisord config)
COPY artifacts/docker/featured/rootfs.agent /

EXPOSE 80
ENTRYPOINT ["/startup.sh"]
