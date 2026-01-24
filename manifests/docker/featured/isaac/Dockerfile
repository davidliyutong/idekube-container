# These arguments are passed in via the docker build command
ARG REGISTRY=docker.io \
    AUTHOR=davidliyutong \
    NAME=idekube-container \
    GIT_TAG=unknown \
    TAG_POSTFIX=

ARG ISSAC_VERSION=4.2.0
FROM nvcr.io/nvidia/isaac-sim:${ISSAC_VERSION} AS isaac

FROM ${REGISTRY}/${AUTHOR}/${NAME}:featured-base-${GIT_TAG}${TAG_POSTFIX} AS system

# Copy the resources
COPY --from=isaac /isaac-sim /opt/isaac-sim

ENV MKL_NUM_THREADS=1 \
    NUMEXPR_NUM_THREADS=1 \
    OMP_NUM_THREADS=1 \
    PATH=/opt/isaac-sim/engine/engine/build/linux-x86_64/release:/opt/isaac-sim/engine/engine/build/linux-x86_64/release/bin:/opt/isaac-sim/engine/engine/build/linux-x86_64/release/tools:/opt/isaac-sim/engine/engine/build/linux-x86_64/release/samples:/opt/isaac-sim/engine/engine/build/linux-x86_64/release/deploy:/opt/isaac-sim/engine/engine/build/linux-x86_64/release/deploy/bin:/opt/isaac-sim/engine/engine/build/linux-x86_64/release/deploy/tools:/opt/isaac-sim/engine/engine/build/linux-x86_64/release/deploy/samples:$PATH
