#!/bin/bash

source scripts/docker_common.sh

arch=$(uname -m)
# if arch equals to aarch64, then set the arch to arm64, if arch equals to x86_64, then set the arch to amd64
if [ "$arch" == "aarch64" ]; then
  arch="arm64"
elif [ "$arch" == "x86_64" ]; then
  arch="amd64"
fi


# build the image
echo "Building $IMAGE_REF with $BRANCH branch"
echo "Build Args: $DOCKER_BUILD_ARGS"
docker build $DOCKER_BUILD_ARGS . -t $IMAGE_REF-$arch -f manifests/docker/$BRANCH/Dockerfile

# remove dangling images
danglingimages=$(docker images --filter "dangling=true" -q); \
if [[ $danglingimages != "" ]]; then \
  docker rmi $(docker images --filter "dangling=true" -q); \
fi
