#!/bin/bash
set -e

source scripts/shell/qemu_common.sh

# Ensure BRANCHES, REGISTRY, AUTHOR, NAME, GIT_TAG, and ARCH are set
if [ -z "$ARCH" ]; then
    echo "docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX"
    docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX
else
    echo "docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX-$ARCH"
    docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX-$ARCH
fi