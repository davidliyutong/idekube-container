#!/bin/bash

source scripts/docker_common.sh

# Ensure BRANCHES, REGISTRY, AUTHOR, NAME, GIT_TAG, and ARCH are set
echo "Publishing for branch $branch"
echo "docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG-$ARCH"
docker push $REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG-$ARCH
done