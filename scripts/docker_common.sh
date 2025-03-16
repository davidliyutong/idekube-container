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

if [[ -z $BRANCH ]]; then
  echo "BRANCH is not set"
  exit 1
fi

# set default values
REGISTRY=${REGISTRY:-"docker.io"}
AUTHOR=${AUTHOR:-"davidliyutong"}
NAME=${NAME:-"idekube-container"}

# set default values for APT_MIRROR, USE_APT_MIRROR, PIP_MIRROR_URL, USE_PIP_MIRROR
APT_MIRROR=${APT_MIRROR:-"mirror.sjtu.edu.cn"}
USE_APT_MIRROR=${USE_APT_MIRROR:-"true"}
PIP_MIRROR_URL=${PIP_MIRROR_URL:-"https://mirror.sjtu.edu.cn/pypi/web/simple"}
USE_PIP_MIRROR=${USE_PIP_MIRROR:-"true"}

# set GIT_TAG variable
GIT_TAG=${GIT_TAG:-latest}
GIT_TAG=$(git tag --list --sort=-v:refname | head -n 1|| echo $GIT_TAG)
DOCKER_BRANCH=$(echo $BRANCH | sed 's/\//-/g')
TAG=$DOCKER_BRANCH-$GIT_TAG

IMAGE_REF=$REGISTRY/$AUTHOR/$NAME:$TAG

# build docker build args
DOCKER_BUILD_ARGS=$(build_docker_args ".dockerargs")
DOCKER_BUILD_ARGS+=" --build-arg REGISTRY=$REGISTRY"
DOCKER_BUILD_ARGS+=" --build-arg AUTHOR=$AUTHOR"
DOCKER_BUILD_ARGS+=" --build-arg NAME=$NAME"
DOCKER_BUILD_ARGS+=" --build-arg GIT_TAG=$GIT_TAG"
DOCKER_BUILD_ARGS+=" --build-arg APT_MIRROR=$APT_MIRROR"
DOCKER_BUILD_ARGS+=" --build-arg USE_APT_MIRROR=$USE_APT_MIRROR"
DOCKER_BUILD_ARGS+=" --build-arg PIP_MIRROR_URL=$PIP_MIRROR_URL"
DOCKER_BUILD_ARGS+=" --build-arg USE_PIP_MIRROR=$USE_PIP_MIRROR"

# set ARCH variable
ARCH=$(uname -m)
# if ARCH equals to aarch64, then set the ARCH to arm64, if ARCH equals to x86_64, then set the ARCH to amd64
if [ "$ARCH" == "aarch64" ]; then
  ARCH="arm64"
elif [ "$ARCH" == "x86_64" ]; then
  ARCH="amd64"
fi
