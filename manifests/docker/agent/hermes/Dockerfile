# syntax=docker/dockerfile:1
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

FROM ${REGISTRY}/${AUTHOR}/${NAME}:agent-base-${GIT_TAG}${TAG_POSTFIX} AS system

ARG HERMES_VERSION=main

# Install Hermes Agent + dependencies (ripgrep, uv)
RUN --mount=type=bind,source=manifests/install-scripts/setup-hermes.sh,target=/tmp/setup-hermes.sh \
    export HERMES_VERSION=${HERMES_VERSION}; bash /tmp/setup-hermes.sh

# Supervisor program (hermes gateway with embedded API server)
COPY manifests/docker/agent/hermes/hermes-gateway.conf /etc/supervisor/conf.d/hermes-gateway.conf

# Startup bootstrap hook
COPY manifests/docker/agent/hermes/00-hermes-bootstrap.sh /etc/idekube/startup.bash/00-hermes-bootstrap.sh
RUN chmod +x /etc/idekube/startup.bash/00-hermes-bootstrap.sh

