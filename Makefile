.PHONY: build build_all buildx buildx_all publish publish_all publishx publishx_all manifest manifest_all rmmanifest rmmanifest_all manifest_qemu rmmanifest_qemu debug_qemu_root dev.run debug set_type

# Include .env file if it exists
-include .env
export

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
IMAGES_QEMU := $(ARCHS:%=$(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG)-%)
BRANCHES = featured/base featured/speit featured/dind featured/ros2 coder/base coder/lite jupyter/base jupyter/speit # order is important
BRANCHES_ASCEND =  featured/base featured/speit-ascendai jupyter/base jupyter/speit-ascendai

include scripts/make/docker.mk
include scripts/make/qemu.mk

dev.run:
	docker run --name idekube-container -it --rm -p 8080:80 -p 8888:8888 -e IDEKUBE_INIT_HOME=true $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-${ARCH}

debug: build dev.run

# 合并 set_base 和 set_ascend 为 set_env，使用 make set_env TYPE=base 或 TYPE=ascend
set_type:
	@if [ "$(TYPE)" = "base" ]; then \
		rm -f .dockerargs && ln -s .dockerargs.base .dockerargs; \
		rm -f .env && ln -s .env.base .env; \
	elif [ "$(TYPE)" = "ascend" ]; then \
		rm -f .dockerargs && ln -s .dockerargs.ascend .dockerargs; \
		rm -f .env && ln -s .env.ascend .env; \
	else \
		echo "Usage: make set_env TYPE=base|ascend" && exit 1; \
	fi

