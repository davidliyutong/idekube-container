#!/bin/bash
set -e

# ARCH=none causes qemu_common.sh to produce the arch-suffix-less base tag
export ARCH=none
source scripts/shell/qemu_common.sh

BASE_TAG="$REGISTRY/$AUTHOR/$NAME:$DOCKER_BRANCH-$GIT_TAG$TAG_POSTFIX"

echo "Creating multi-arch manifest: $BASE_TAG"
docker buildx imagetools create \
    -t "$BASE_TAG" \
    "${BASE_TAG}-amd64" \
    "${BASE_TAG}-arm64"
