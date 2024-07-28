#!/bin/bash

function build_docker_args {
  env_file=$1
  if [[ ! -f "$env_file" ]]; then
    return
  fi
  # start building docker build command
  local build_args=""

  # read each line in .env file
  while IFS='=' read -r key value
  do
    # ignore if line is empty
    [ -z "$key" ] && continue

    # append each key/value pair as build-arg to the command
    build_args+=" --build-arg $key=$value"
  done < "$env_file"

  # execute the command
  echo $build_args
}


REGISTRY=${REGISTRY:-"docker.io"}
AUTHOR=${AUTHOR:-"davidliyutong"}
NAME=${NAME:-"idekube-container"}
APT_MIRROR=${APT_MIRROR:-"mirror.sjtu.edu.cn"}
if [[ -z $BRANCH ]]; then
  echo "BRANCH is not set"
  exit 1
fi

# set ARCH variable
arch=$(uname -m)
if [[ $arch == "x86_64" ]]; then
  ARCH="amd64"
else
  ARCH=$arch
fi
# fix machine name for arm64
if [[ $arch == "arm64" ]]; then
  MACHINE="aarch64"
else
  MACHINE=$arch
fi

# set GIT_TAG variable
GIT_TAG=${GIT_TAG:-latest}
GIT_TAG=$(git describe --tags --abbrev=2 2>/dev/null || echo $GIT_TAG)
DOCKER_BRANCH=$(echo $BRANCH | sed 's/\//-/g')
TAG=$DOCKER_BRANCH-$GIT_TAG

IMAGE_REF=$REGISTRY/$AUTHOR/$NAME:$TAG-$ARCH

# execute the command
DOCKER_BUILD_ARGS=$(build_docker_args "envfile")
DOCKER_BUILD_ARGS+=" --build-arg REGISTRY=$REGISTRY"
DOCKER_BUILD_ARGS+=" --build-arg AUTHOR=$AUTHOR"
DOCKER_BUILD_ARGS+=" --build-arg NAME=$NAME"
DOCKER_BUILD_ARGS+=" --build-arg DOCKER_BRANCH=$DOCKER_BRANCH"
DOCKER_BUILD_ARGS+=" --build-arg GIT_TAG=$GIT_TAG"
DOCKER_BUILD_ARGS+=" --build-arg ARCH=$ARCH"
DOCKER_BUILD_ARGS+=" --build-arg MACHINE=$MACHINE"
DOCKER_BUILD_ARGS+=" --build-arg APT_MIRROR=$APT_MIRROR"

# build the image
echo "Building $IMAGE_REF with $BRANCH branch"
echo "Build Args: $DOCKER_BUILD_ARGS"
docker build $DOCKER_BUILD_ARGS . -t $IMAGE_REF -f manifests/docker/$BRANCH/Dockerfile

# remove dangling images
danglingimages=$(docker images --filter "dangling=true" -q); \
if [[ $danglingimages != "" ]]; then \
  docker rmi $(docker images --filter "dangling=true" -q); \
fi

