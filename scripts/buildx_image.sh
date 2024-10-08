#!/bin/bash

source scripts/docker_common.sh

# List if thereare idekube buildx, if not, create one
docker buildx ls | grep idekube || docker buildx create --name idekube --driver docker-container

# build the image
echo "Building $IMAGE_REF with $BRANCH branch"
echo "Build Args: $DOCKER_BUILD_ARGS"
docker buildx build --builder idekube --platform=linux/amd64,linux/arm64 $DOCKER_BUILD_ARGS . -t $IMAGE_REF -f manifests/docker/$BRANCH/Dockerfile
# Import the images
docker buildx build --builder idekube --platform=linux/arm64 $DOCKER_BUILD_ARGS --load . -t $IMAGE_REF-arm64 -f manifests/docker/$BRANCH/Dockerfile
docker buildx build --builder idekube --platform=linux/amd64 $DOCKER_BUILD_ARGS --load . -t $IMAGE_REF-amd64 -f manifests/docker/$BRANCH/Dockerfile
