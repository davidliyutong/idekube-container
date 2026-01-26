#!/bin/bash
set -e

source scripts/shell/docker_common.sh

# push the image to the registry
echo "Publishing for branch $branch"
if [ -z "$ARCH" ]; then
    echo "docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX"
    docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX
else
    echo "docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX-$ARCH"
    docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX-$ARCH
fi