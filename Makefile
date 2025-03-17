.PHONY: build build_all buildx buildx_all publish publish_all publishx publishx_all manifest manifest_all rmmanifest dev.run debug

# Build variable
REGISTRY ?= docker.io
AUTHOR   ?= davidliyutong
NAME     ?= idekube-container
BRANCH   ?= featured/base

# Test variable
GIT_TAG  ?= latest
GIT_TAG  := $(shell git tag --list --sort=-v:refname | head -n 1 || echo $(GIT_TAG))
TAG	     ?= $(subst /,-,$(BRANCH))-$(GIT_TAG)
ARCH     := $(shell arch=$$(uname -m); if [ "$$arch" = "x86_64" ]; then echo amd64; else echo $$arch; fi)

# CI/CD variable
ARCHS    = amd64 arm64
IMAGES   := $(ARCHS:%=$(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-%)
BRANCHES = featured/base featured/speit featured/dind featured/ros2 coder/base coder/lite jupyter/base jupyter/speit # order is important

include scripts/docker.mk

dev.run:
	docker run --name idekube-container -it --rm -p 8080:80 -p 8888:8888 -e IDEKUBE_INGRESS_PATH=/davidliyutong -e IDEKUBE_INIT_HOME=true $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-${ARCH}

debug: build dev.run

third_party/.ready: manifests/deps.repo
	vcs import < manifests/deps.repo && touch third_party/.ready

pull_deps: third_party/.ready

