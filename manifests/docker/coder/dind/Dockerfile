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

ENV PYTHONIOENCODING=utf-8
ARG DOCKER_CHANNEL=stable \
    DOCKER_VERSION=27.2.1 \
    DOCKER_COMPOSE_VERSION=v2.29.2 \
    BUILDX_VERSION=v0.16.2 \
    DEBUG=false

# Install Docker's dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates iptables

# Set iptables-legacy for Ubuntu 22.04 and newer
RUN if dpkg --compare-versions $(lsb_release -r | awk '{print $2}') gt 20.04; then \
        echo "Setting iptables-legacy for Ubuntu 22.04 and newer"; \
        update-alternatives --set iptables /usr/sbin/iptables-legacy; \
    fi

# Install Docker and buildx
RUN arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) dockerArch='x86_64' ; buildx_arch='linux-amd64' ;; \
        armhf) dockerArch='armel' ; buildx_arch='linux-arm-v6' ;; \
        armv7) dockerArch='armhf' ; buildx_arch='linux-arm-v7' ;; \
        aarch64) dockerArch='aarch64' ; buildx_arch='linux-arm64' ;; \
        *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;; \
    esac && \
    wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz" && \
    tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ && \
    rm docker.tgz && \
    wget -O docker-buildx "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.${buildx_arch}" && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    chmod +x docker-buildx && \
    mv docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx && \
    dockerd --version && \
    docker --version && \
    docker buildx version

# Install Docker Compose
RUN set -eux; \
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    docker-compose version && \
    ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

# Setup docker supervisord
COPY manifests/misc/dind/modprobe /usr/local/bin/
RUN chmod +x /usr/local/bin/modprobe
COPY manifests/misc/dind/dockerd.conf/ /etc/supervisor/conf.d/dockerd.conf

# Configure user permission
RUN groupadd docker && usermod -aG docker idekube
