# ──────────────────────────────────────────────────────────────
# Branch dependency graph
# Only list branches whose Dockerfile FROM references another
# project image.  Unlisted branches are roots (FROM external BASE_IMAGE).
# ──────────────────────────────────────────────────────────────
DEPS_featured/speit          := featured/base
DEPS_featured/speit-ai       := featured/base
DEPS_featured/dind           := featured/base
DEPS_featured/kathara        := featured/dind
DEPS_featured/ros2           := featured/base
DEPS_jupyter/speit-ai        := jupyter/base
DEPS_jupyter/speit-ascendai  := jupyter/base

# ──────────────────────────────────────────────────────────────
# Frontend stamp file – avoids redundant rebuilds
# ──────────────────────────────────────────────────────────────
FRONTEND_STAMP := frontend/dist/.build_stamp

$(FRONTEND_STAMP): frontend/package.json frontend/package-lock.json frontend/vite.config.ts \
                   $(wildcard frontend/src/*) $(wildcard frontend/src/**/*) $(wildcard frontend/*.html)
	cd frontend && npm ci && npm run build
	@touch $@

frontend: $(FRONTEND_STAMP)

# ──────────────────────────────────────────────────────────────
# Per-branch target generator
#   $(1) = action prefix  (build, buildx, publishx, publish)
#   $(2) = branch name    (e.g. featured/base)
#   $(3) = shell script   (e.g. scripts/shell/build_image.sh)
# ──────────────────────────────────────────────────────────────
define branch-action-rule
.PHONY: _$(1)/$(2)
_$(1)/$(2): $(foreach d,$(DEPS_$(2)),_$(1)/$(d))
	@echo "$(1): $(2)"
	@export REGISTRY=$$(REGISTRY) AUTHOR=$$(AUTHOR) NAME=$$(NAME) BRANCH=$(2); bash $(3)
endef

# Generate targets for every (action × branch) pair
$(foreach b,$(BRANCHES),$(eval $(call branch-action-rule,build,$(b),scripts/shell/build_image.sh)))
$(foreach b,$(BRANCHES),$(eval $(call branch-action-rule,buildx,$(b),scripts/shell/buildx_image.sh)))
$(foreach b,$(BRANCHES),$(eval $(call branch-action-rule,publishx,$(b),scripts/shell/publishx_image.sh)))
$(foreach b,$(BRANCHES),$(eval $(call branch-action-rule,publish,$(b),scripts/shell/publish_image.sh)))

$(foreach b,$(BRANCHES_ASCEND),$(eval $(call branch-action-rule,build_ascend,$(b),scripts/shell/build_image.sh)))
$(foreach b,$(BRANCHES_ASCEND),$(eval $(call branch-action-rule,buildx_ascend,$(b),scripts/shell/buildx_image.sh)))
$(foreach b,$(BRANCHES_ASCEND),$(eval $(call branch-action-rule,publishx_ascend,$(b),scripts/shell/publishx_image.sh)))
$(foreach b,$(BRANCHES_ASCEND),$(eval $(call branch-action-rule,publish_ascend,$(b),scripts/shell/publish_image.sh)))

# ──────────────────────────────────────────────────────────────
# Single-branch targets  (user-facing, e.g. make build BRANCH=featured/base)
# ──────────────────────────────────────────────────────────────
build: frontend
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/build_image.sh

buildx: frontend
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/buildx_image.sh

publish: build
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/publish_image.sh

publishx: frontend
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/publishx_image.sh

# ──────────────────────────────────────────────────────────────
# Parallel _all targets
#   Frontend is built once by the outer make; the sub-make only
#   resolves the branch dependency DAG with -j$(MAX_PARALLEL).
# ──────────────────────────────────────────────────────────────
build_all: frontend
	@$(MAKE) -j$(MAX_PARALLEL) $(foreach b,$(BRANCHES),_build/$(b))

buildx_all: frontend
	@$(MAKE) -j$(MAX_PARALLEL) $(foreach b,$(BRANCHES),_buildx/$(b))

publishx_all: frontend
	@$(MAKE) -j$(MAX_PARALLEL) $(foreach b,$(BRANCHES),_publishx/$(b))

publish_all: frontend
	@$(MAKE) -j$(MAX_PARALLEL) $(foreach b,$(BRANCHES),_publish/$(b))

build_all_ascend: frontend
	@$(MAKE) -j$(MAX_PARALLEL) $(foreach b,$(BRANCHES_ASCEND),_build_ascend/$(b))

buildx_all_ascend: frontend
	@$(MAKE) -j$(MAX_PARALLEL) $(foreach b,$(BRANCHES_ASCEND),_buildx_ascend/$(b))

publishx_all_ascend: frontend
	@$(MAKE) -j$(MAX_PARALLEL) $(foreach b,$(BRANCHES_ASCEND),_publishx_ascend/$(b))

publish_all_ascend: frontend
	@$(MAKE) -j$(MAX_PARALLEL) $(foreach b,$(BRANCHES_ASCEND),_publish_ascend/$(b))

# ──────────────────────────────────────────────────────────────
# Manifest targets  (unchanged – no image builds, no parallelism needed)
# ──────────────────────────────────────────────────────────────
manifest:
	@set -e; \
	docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG) || true;
	docker manifest create $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG) $(IMAGES)
	for arch in $(ARCHS); \
	do \
		echo docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG) $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$$arch; \
		docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG) $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$$arch; \
	done
	docker manifest push $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)

manifest_all:
	@set -e; \
	for branch in $(BRANCHES); do \
		TAG=$$(echo $$branch | sed 's/\//-/g')-$(GIT_TAG); \
		docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG || true ;  \
		docker manifest create $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG $(ARCHS:%=$(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-%); \
		for arch in $(ARCHS); do \
			echo docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-$$arch; \
			docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-$$arch; \
		done; \
		docker manifest push $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG; \
	done

manifest_all_ascend:
	@set -e; \
	for branch in $(BRANCHES_ASCEND); do \
		TAG=$$(echo $$branch | sed 's/\//-/g')-$(GIT_TAG); \
		docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG || true ;  \
		docker manifest create $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG $(ARCHS:%=$(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-%); \
		for arch in $(ARCHS); do \
			echo docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-$$arch; \
			docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-$$arch; \
		done; \
		docker manifest push $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG; \
	done

rmmanifest:
	@set -e; \
	for arch in $(ARCHS); \
	do \
		hub-tool tag rm $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$$arch || true	; \
	done

rmmanifest_all:
	@set -e; \
	for branch in $(BRANCHES); do \
		TAG=$$(echo $$branch | sed 's/\//-/g')-$(GIT_TAG); \
		for arch in $(ARCHS); \
		do \
			hub-tool tag rm $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-$$arch || true; \
		done; \
	done

rmmanifest_all_ascend:
	@set -e; \
	for branch in $(BRANCHES_ASCEND); do \
		TAG=$$(echo $$branch | sed 's/\//-/g')-$(GIT_TAG); \
		for arch in $(ARCHS); \
		do \
			hub-tool tag rm $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-$$arch || true; \
		done; \
	done
