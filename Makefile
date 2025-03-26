.PHONY: build build_all buildx buildx_all publish publish_all publishx publishx_all manifest manifest_all rmmanifest dev.run debug

# Build variable
REGISTRY 			?= docker.io
AUTHOR   			?= davidliyutong
NAME    			?= idekube-container
BRANCH   			?= featured/base
# Base Image Selection
BASE_IMAGE   		?= ubuntu:24.04
BASE_IMAGE_VERSION 	?= $(shell echo $(BASE_IMAGE) | cut -d: -f2)
# Test variable
GIT_TAG  			?= latest
GIT_TAG  			:= $(shell git tag --list --sort=-v:refname | head -n 1 || echo $(GIT_TAG))
TAG	     			?= $(subst /,-,$(BRANCH))-$(BASE_IMAGE_VERSION)-$(GIT_TAG)
ARCH     			:= $(shell arch=$$(uname -m); if [ "$$arch" = "x86_64" ]; then echo amd64; else echo $$arch; fi)

third_party/.ready: manifests/deps.repo
	vcs import < manifests/deps.repo && touch third_party/.ready

pull_deps: third_party/.ready

include scripts/docker.mk

dev.run:
	docker run \
		--name idekube-container \
		-it --rm \
		-p 8080:80 \
		-e IDEKUBE_INGRESS_PATH=/davidliyutong \
		-e IDEKUBE_INIT_HOME=true \
		$(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-${ARCH}

debug: build dev.run



