.PHONY: build build_all publish publish_all manifest rmmanifest run

# Build variable
REGISTRY ?= docker.io
AUTHOR   ?= davidliyutong
NAME     ?= idekube-container
BRANCH   ?= coder/base

# Test variable
GIT_TAG  ?= latest
GIT_TAG  := $(shell git describe --tags --abbrev=2>/dev/null || echo $(GIT_TAG))
TAG	     ?= $(subst /,-,$(BRANCH))-$(GIT_TAG)
ARCH     := $(shell arch=$$(uname -m); if [[ $$arch == "x86_64" ]]; then echo amd64; else echo $$arch; fi)

# CI/CD variable
ARCHS    = amd64 arm64
IMAGES   := $(ARCHS:%=$(REPO)$(NAME):$(TAG)-%)
PLATFORMS := $$(first="True"; for a in $(ARCHS); do if [[ $$first == "True" ]]; then printf "linux/%s" $$a; first="False"; else printf ",linux/%s" $$a; fi; done)
BRANCHES = coder/base coder/speit jupyter/base


build: pull_deps
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/build_image.sh

build_all: pull_deps
	@for branch in $(BRANCHES); do \
		echo "Building for branch $$branch"; \
		export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=$$branch; bash scripts/build_image.sh; \
	done

publish: build
	docker push $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$(ARCH)

publish_all: build_all
	@for branch in $(BRANCHES); do \
		echo "Publishing for branch $$branch"; \
		docker push $(REGISTRY)/$(AUTHOR)/$(NAME):$(subst /,-,$$branch))-$(GIT_TAG)-$(ARCH); \
	done

manifest:
	docker manifest create $(REPO)$(NAME):$(TAG) $(IMAGES)
	@for arch in $(ARCHS); \
	do \
		echo docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)$(NAME):$(TAG) $(REGISTRY)/$(AUTHOR)$(NAME):$(TAG)-$$arch; \
		docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)$(NAME):$(TAG) $(REGISTRY)/$(AUTHOR)$(NAME):$(TAG)-$$arch; \
	done
	docker manifest push $(REGISTRY)/$(AUTHOR)$(NAME):$(TAG)

rmmanifest:
	docker manifest rm $(REGISTRY)/$(AUTHOR)$(NAME):$(TAG)

run:
	docker run --name idekube-container -it --rm -p 8080:80 -p 8888:8888 -e IDEKUBE_INGRESS_HOST=localhost:8080 -e IDEKUBE_INGRESS_PATH=/davidliyutong -e IDEKUBE_INIT_HOME=true $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-${ARCH}

manifests:
	@export BRANCH=${BRANCH} IMAGE_REF=$(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-${ARCH}; bash scripts/generate_manifests.sh

debug: build run

third_party/noVNC: manifests/deps.repo
	vcs import < manifests/deps.repo

pull_deps: third_party/noVNC

