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

# set GIT_TAG variable
GIT_TAG=${GIT_TAG:-latest}
GIT_TAG=$(git describe --tags --abbrev=2 2>/dev/null || echo $GIT_TAG)
DOCKER_BRANCH=$(echo $BRANCH | sed 's/\//-/g')
TAG=$DOCKER_BRANCH-$GIT_TAG

IMAGE_REF=$REGISTRY/$AUTHOR/$NAME:$TAG

# execute the command
DOCKER_BUILD_ARGS=$(build_docker_args ".dockerargs")
DOCKER_BUILD_ARGS+=" --build-arg REGISTRY=$REGISTRY"
DOCKER_BUILD_ARGS+=" --build-arg AUTHOR=$AUTHOR"
DOCKER_BUILD_ARGS+=" --build-arg NAME=$NAME"
DOCKER_BUILD_ARGS+=" --build-arg DOCKER_BRANCH=$DOCKER_BRANCH"
DOCKER_BUILD_ARGS+=" --build-arg GIT_TAG=$GIT_TAG"
DOCKER_BUILD_ARGS+=" --build-arg ARCH=$ARCH"
DOCKER_BUILD_ARGS+=" --build-arg MACHINE=$MACHINE"
DOCKER_BUILD_ARGS+=" --build-arg APT_MIRROR=$APT_MIRROR"
