#!/bin/bash

source scripts/shell/docker_common.sh
# ARCH, BRANCH, IMAGE_REF, DOCKER_BUILD_ARGS

# build the image
echo "Building $IMAGE_REF with $BRANCH branch"
echo "Build Args: $DOCKER_BUILD_ARGS"

set -e
docker build $DOCKER_BUILD_ARGS . -t $IMAGE_REF-$ARCH -t $IMAGE_REF -f manifests/docker/$BRANCH/Dockerfile

# remove dangling images
danglingimages=$(docker images --filter "dangling=true" -q); \
if [[ $danglingimages != "" ]]; then \
  docker rmi $(docker images --filter "dangling=true" -q); \
fi
