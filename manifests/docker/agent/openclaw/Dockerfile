# syntax=docker/dockerfile:1
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

FROM ${REGISTRY}/${AUTHOR}/${NAME}:agent-base-${GIT_TAG}${TAG_POSTFIX} AS system

ARG OPENCLAW_VERSION=latest

# Install openclaw gateway
RUN --mount=type=bind,source=manifests/install-scripts/setup-openclaw.sh,target=/tmp/setup-openclaw.sh \
    export OPENCLAW_VERSION=${OPENCLAW_VERSION}; bash /tmp/setup-openclaw.sh

# Add openclaw supervisor program
COPY manifests/docker/agent/openclaw/openclaw.conf /etc/supervisor/conf.d/openclaw.conf

# Add openclaw bootstrap startup hook
COPY manifests/docker/agent/openclaw/00-openclaw-bootstrap.sh /etc/idekube/startup.bash/00-openclaw-bootstrap.sh
RUN chmod +x /etc/idekube/startup.bash/00-openclaw-bootstrap.sh

# Override nginx config to add /agent location block
COPY manifests/docker/agent/openclaw/default /etc/nginx/sites-enabled/default

# Override health config for openclaw variant
COPY manifests/docker/agent/openclaw/health.json /etc/idekube/health.json
