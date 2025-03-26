#!/bin/bash
set -e

source scripts/shell/docker_common.sh

# List if thereare idekube buildx, if not, create one
docker buildx ls | grep idekube || docker buildx create --name idekube --driver docker-container

# build the image
echo "Publishing $IMAGE_REF with $BRANCH branch"
echo "Build Args: $DOCKER_BUILD_ARGS"
docker buildx build --builder idekube --platform=linux/amd64,linux/arm64 $DOCKER_BUILD_ARGS --push . -t $IMAGE_REF -f manifests/docker/$BRANCH/Dockerfile

# second build for latest tag
docker buildx build --builder idekube --platform=linux/amd64,linux/arm64 $DOCKER_BUILD_ARGS --push . -t $IMAGE_REF_LATEST -f manifests/docker/$BRANCH/Dockerfile
