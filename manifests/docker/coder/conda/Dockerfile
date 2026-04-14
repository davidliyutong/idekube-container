# syntax=docker/dockerfile:1
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

FROM ${REGISTRY}/${AUTHOR}/${NAME}:coder-base-${GIT_TAG}${TAG_POSTFIX} AS system

ARG MINICONDA_VERSION=latest

# Install Miniconda (the only addition over coder/base)
RUN --mount=type=bind,source=manifests/install-scripts/setup-miniconda.sh,target=/tmp/setup-miniconda.sh \
    export MINICONDA_VERSION=${MINICONDA_VERSION}; bash /tmp/setup-miniconda.sh
ENV PATH=/opt/miniconda3/bin:$PATH
