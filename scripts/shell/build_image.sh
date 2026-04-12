#!/bin/bash

source scripts/shell/docker_common.sh
# ARCH, BRANCH, IMAGE_REF, DOCKER_BUILD_ARGS

# build the image
echo "Building $IMAGE_REF with $BRANCH branch"
echo "Build Args: $DOCKER_BUILD_ARGS"

set -e
# Enables Docker BuildKit, a modern build backend for Docker that provides improved performance,
# caching, and additional features compared to the legacy builder. BuildKit is required for
# certain advanced Docker build features like inline cache, external cache sources, and
# better layer caching strategies.
export DOCKER_BUILDKIT=1
docker build $DOCKER_BUILD_ARGS . -t $IMAGE_REF-$ARCH -t $IMAGE_REF -f manifests/docker/$BRANCH/Dockerfile

# remove dangling images
danglingimages=$(docker images --filter "dangling=true" -q); \
if [[ $danglingimages != "" ]]; then \
  docker rmi $(docker images --filter "dangling=true" -q) || true; \
fi
