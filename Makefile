.PHONY: build build_all buildx buildx_all publish publish_all publishx publishx_all \
       build_all_ascend buildx_all_ascend publishx_all_ascend publish_all_ascend \
       manifest manifest_all manifest_all_ascend rmmanifest rmmanifest_all rmmanifest_all_ascend \
       prepare_qemu_files build_qemu_tools build_qemu_root build_qemu publish_qemu \
       dev.run debug set_type frontend list deps ci-matrix \
       test_deps test test_all test_all_ascend

# Include .env file if it exists
-include .env
export

# Build variables
REGISTRY ?= docker.io
AUTHOR   ?= davidliyutong
NAME     ?= idekube-container
BRANCH   ?= featured/base
LINEUP   ?= base

# Derived variables (used by dev.run)
GIT_TAG  := $(shell git tag --list --sort=-v:refname | head -n 1 || echo $(GIT_TAG))
TAG      ?= $(subst /,-,$(BRANCH))-$(GIT_TAG)
ARCH     := $(shell arch=$$(uname -m); if [ "$$arch" = "x86_64" ]; then echo amd64; else echo $$arch; fi)

# Maximum parallel branch builds
MAX_PARALLEL ?= 2

# ──────────────────────────────────────────────────────────────
# Frontend (unchanged)
# ──────────────────────────────────────────────────────────────
FRONTEND_STAMP := frontend/dist/.build_stamp

$(FRONTEND_STAMP): frontend/package.json frontend/package-lock.json frontend/vite.config.ts \
                   $(wildcard frontend/src/*) $(wildcard frontend/src/**/*) $(wildcard frontend/*.html)
	cd frontend && npm ci && npm run build
	@touch $@

frontend: $(FRONTEND_STAMP)

# ──────────────────────────────────────────────────────────────
# Single-image targets
# ──────────────────────────────────────────────────────────────
build: frontend
	@python3 build.py build $(BRANCH) --lineup=$(LINEUP)

buildx: frontend
	@python3 build.py buildx $(BRANCH) --lineup=$(LINEUP)

publishx: frontend
	@python3 build.py publishx $(BRANCH) --lineup=$(LINEUP)

publish: build
	@python3 build.py publish $(BRANCH) --lineup=$(LINEUP)

# ──────────────────────────────────────────────────────────────
# All-images targets (base lineup)
# ──────────────────────────────────────────────────────────────
build_all: frontend
	@python3 build.py build-all --lineup=base --parallel=$(MAX_PARALLEL)

buildx_all: frontend
	@python3 build.py buildx-all --lineup=base --parallel=$(MAX_PARALLEL)

publishx_all: frontend
	@python3 build.py publishx-all --lineup=base --parallel=$(MAX_PARALLEL)

publish_all: frontend
	@python3 build.py publish-all --lineup=base --parallel=$(MAX_PARALLEL)

# ──────────────────────────────────────────────────────────────
# All-images targets (ascend lineup)
# ──────────────────────────────────────────────────────────────
build_all_ascend: frontend
	@python3 build.py build-all --lineup=ascend --parallel=$(MAX_PARALLEL)

buildx_all_ascend: frontend
	@python3 build.py buildx-all --lineup=ascend --parallel=$(MAX_PARALLEL)

publishx_all_ascend: frontend
	@python3 build.py publishx-all --lineup=ascend --parallel=$(MAX_PARALLEL)

publish_all_ascend: frontend
	@python3 build.py publish-all --lineup=ascend --parallel=$(MAX_PARALLEL)

# ──────────────────────────────────────────────────────────────
# Info targets
# ──────────────────────────────────────────────────────────────
list:
	@python3 build.py list --lineup=$(LINEUP)

deps:
	@python3 build.py deps $(BRANCH)

ci-matrix:
	@python3 build.py ci-matrix --lineup=$(LINEUP) --pretty

# ──────────────────────────────────────────────────────────────
# Manifest targets
# ──────────────────────────────────────────────────────────────
manifest:
	@python3 build.py manifest $(BRANCH) --lineup=$(LINEUP)

manifest_all:
	@python3 build.py manifest-all --lineup=base

manifest_all_ascend:
	@python3 build.py manifest-all --lineup=ascend

rmmanifest:
	@python3 build.py rmmanifest $(BRANCH) --lineup=$(LINEUP)

rmmanifest_all:
	@python3 build.py rmmanifest-all --lineup=base

rmmanifest_all_ascend:
	@python3 build.py rmmanifest-all --lineup=ascend

# ──────────────────────────────────────────────────────────────
# QEMU targets
# ──────────────────────────────────────────────────────────────
prepare_qemu_files:
	@python3 build.py qemu-prepare

build_qemu_tools:
	@python3 build.py qemu-build-tools

build_qemu_root:
	@python3 build.py qemu-build-root $(BRANCH)

build_qemu:
	@python3 build.py qemu-build $(BRANCH)

publish_qemu:
	@python3 build.py qemu-publish $(BRANCH)

debug_qemu_root:
	@echo "Starting QEMU VM natively for branch $(BRANCH)..."
	@cd .cache/$(BRANCH)/ && ../../../artifacts/qemu/startup-scripts/run.sh

# ──────────────────────────────────────────────────────────────
# Dev / debug targets
# ──────────────────────────────────────────────────────────────
dev.run:
	docker run --name idekube-container -it --rm -p 8080:80 -p 8888:8888 -e IDEKUBE_INIT_HOME=true $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$(ARCH)

debug: build dev.run

# ──────────────────────────────────────────────────────────────
# Test targets
# ──────────────────────────────────────────────────────────────
TEST_OUTPUT := .cache/test-output

test_deps:
	cd tests && uv sync
	cd tests && uv run playwright install chromium --with-deps

# Single-branch test (mirrors `make build` — reads BRANCH and LINEUP env vars)
test: test_deps
	cd tests && uv run pytest \
		--lineup=$(LINEUP) \
		--branch=$(BRANCH) \
		--output-dir=$(abspath $(TEST_OUTPUT)) \
		--html=$(abspath $(TEST_OUTPUT))/report-$(subst /,-,$(BRANCH)).html --self-contained-html \
		-v --tb=short

# All-branches test (base lineup)
test_all: test_deps
	cd tests && uv run pytest \
		--lineup=base \
		--output-dir=$(abspath $(TEST_OUTPUT)) \
		--html=$(abspath $(TEST_OUTPUT))/report.html --self-contained-html \
		-n $(MAX_PARALLEL) --dist loadgroup \
		-v --tb=short

# All-branches test (ascend lineup)
test_all_ascend: test_deps
	cd tests && uv run pytest \
		--lineup=ascend \
		--output-dir=$(abspath $(TEST_OUTPUT)) \
		--html=$(abspath $(TEST_OUTPUT))/report_ascend.html --self-contained-html \
		-n $(MAX_PARALLEL) --dist loadgroup \
		-v --tb=short

# ──────────────────────────────────────────────────────────────
# Legacy: set_type (kept for backward compat, no longer required)
# ──────────────────────────────────────────────────────────────
set_type:
	@if [ "$(TYPE)" = "base" ]; then \
		rm -f .dockerargs && ln -s .dockerargs.base .dockerargs; \
		rm -f .env && ln -s .env.base .env; \
	elif [ "$(TYPE)" = "ascend" ]; then \
		rm -f .dockerargs && ln -s .dockerargs.ascend .dockerargs; \
		rm -f .env && ln -s .env.ascend .env; \
	else \
		echo "Usage: make set_type TYPE=base|ascend" && exit 1; \
	fi
