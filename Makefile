.PHONY: build run

REGISTRY ?= docker.io
AUTHOR   ?= davidliyutong
NAME     ?= idekube-container
GIT_TAG  ?= latest
GIT_TAG  := $(shell git describe --tags --abbrev=2>/dev/null || echo $(GIT_TAG))
ARCH     := $(shell arch=$$(uname -m); if [[ $$arch == "x86_64" ]]; then echo amd64; else echo $$arch; fi)
BRANCH   ?= coder/base
TAG	     ?= $(subst /,-,$(BRANCH))-$(GIT_TAG)
ARCHS    = amd64 arm64
IMAGES   := $(ARCHS:%=$(REPO)$(NAME):$(TAG)-%)
PLATFORMS := $$(first="True"; for a in $(ARCHS); do if [[ $$first == "True" ]]; then printf "linux/%s" $$a; first="False"; else printf ",linux/%s" $$a; fi; done)


build:
	@export BRANCH=${BRANCH} IMAGE_REF=$(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-${ARCH}; bash scripts/build_image.sh

run:
	docker run --name idekube-container -it --rm -p 8080:80 -p 8888:8888 -e IDEKUBE_INGRESS_HOST=localhost:8080 -e IDEKUBE_INGRESS_PATH=davidliyutong/ $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-${ARCH}

debug: build run

.PHONY: pull_deps
pull_deps:
	vcs import < manifests/deps.repo

