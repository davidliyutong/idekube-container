#!/bin/bash

source scripts/docker_common.sh

# build the image
echo "Building $IMAGE_REF with $BRANCH branch"
echo "Build Args: $DOCKER_BUILD_ARGS"
docker build $DOCKER_BUILD_ARGS . -t $IMAGE_REF -f manifests/docker/$BRANCH/Dockerfile

# remove dangling images
danglingimages=$(docker images --filter "dangling=true" -q); \
if [[ $danglingimages != "" ]]; then \
  docker rmi $(docker images --filter "dangling=true" -q); \
fi

