#!/bin/bash
set -e

source scripts/shell/qemu_common.sh

# Ensure BRANCHES, REGISTRY, AUTHOR, NAME, GIT_TAG, and ARCH are set
echo "Publishing for branch $branch"
docker tag $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG-$ARCH $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-latest-$ARCH

# push the image to the registry
echo "docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG-$ARCH"
docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG-$ARCH

# push the tag latest to the registry
echo "docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-latest-$ARCH"
docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-latest-$ARCH