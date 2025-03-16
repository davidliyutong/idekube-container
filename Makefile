.PHONY: build build_all publish publish_all manifest rmmanifest run

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


build: pull_deps
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/build_image.sh

build_all: pull_deps
	@set -e; \
	for branch in $(BRANCHES); do \
		echo "Building for branch $$branch"; \
		export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=$$branch; bash scripts/build_image.sh; \
	done

buildx: pull_deps
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/buildx_image.sh

buildx_all: pull_deps
	@set -e; \
	for branch in $(BRANCHES); do \
		echo "Building for branch $$branch"; \
		export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=$$branch; bash scripts/buildx_image.sh; \
	done

publish: build
	docker push $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$(ARCH)

publish_all: build_all
	@set -e; \
	for branch in $(BRANCHES); do \
        DOCKER_BRANCH=$$(echo $$branch | sed 's/\//-/g'); \
        echo "Publishing for branch $$branch"; \
        echo "docker push $(REGISTRY)/$(AUTHOR)/$(NAME):$$DOCKER_BRANCH-$(GIT_TAG)-$(ARCH)"; \
        docker push $(REGISTRY)/$(AUTHOR)/$(NAME):$$DOCKER_BRANCH-$(GIT_TAG)-$(ARCH); \
    done

publishx: pull_deps
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/publishx_image.sh

publishx_all: pull_deps
	@set -e; \
	for branch in $(BRANCHES); do \
		echo "Publishing for branch $$branch"; \
		export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=$$branch; bash scripts/publishx_image.sh; \
	done

manifest:
	-docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)
	docker manifest create $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG) $(IMAGES)
	@for arch in $(ARCHS); \
	do \
		echo docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG) $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$$arch; \
		docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG) $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$$arch; \
	done
	docker manifest push $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)

rmmanifest:
	docker manifest rm $(REGISTRY)/$(AUTHOR)$(NAME):$(TAG)

run:
	docker run --name idekube-container -it --rm -p 8080:80 -p 8888:8888 -e IDEKUBE_INGRESS_PATH=/davidliyutong -e IDEKUBE_INIT_HOME=true $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-${ARCH}

debug: build run

third_party/.ready: manifests/deps.repo
	vcs import < manifests/deps.repo && touch third_party/.ready

pull_deps: third_party/.ready

