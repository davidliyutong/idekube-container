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

if [[ -z $IMAGE_REF ]]; then
  echo "IMAGE_REF is not set"
  exit 1
fi

if [[ -z $BRANCH ]]; then
  echo "BRANCH is not set"
  exit 1
fi

# execute the command
DOCKER_BUILD_ARGS=$(build_docker_args "envfile")
# echo "docker build $DOCKER_BUILD_ARGS ."

echo "Building $IMAGE_REF with $BRANCH branch"
docker build $DOCKER_BUILD_ARGS . -t $IMAGE_REF -f manifests/docker/$BRANCH/Dockerfile

# remove dangling images
danglingimages=$(docker images --filter "dangling=true" -q); \
if [[ $danglingimages != "" ]]; then \
  docker rmi $(docker images --filter "dangling=true" -q); \
fi

