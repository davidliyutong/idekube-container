
build:
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/build_image.sh

build_all:
	@set -e; \
	for branch in $(BRANCHES); do \
		echo "Building for branch $$branch"; \
		export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=$$branch; bash scripts/shell/build_image.sh; \
	done

buildx:
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/buildx_image.sh

buildx_all:
	@set -e; \
	for branch in $(BRANCHES); do \
		echo "Building for branch $$branch"; \
		export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=$$branch; bash scripts/shell/buildx_image.sh; \
	done

publish: build
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/publish_image.sh

publish_all: build_all
	@set -e; \
	for branch in $(BRANCHES); do \
		echo "Publishing for branch $$branch"; \
		@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=$$branch; bash scripts/shell/publish_image.sh; \
	done

publishx:
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/publishx_image.sh

publishx_all:
	@set -e; \
	for branch in $(BRANCHES); do \
		echo "Publishing for branch $$branch"; \
		export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=$$branch; bash scripts/shell/publishx_image.sh; \
	done

manifest:
	@set -e; \
	-docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)
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

rmmanifest:
	@set -e; \
	for arch in $(ARCHS); \
	do \
		docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$$arch; \
	done

rmmanifest_all:
	@set -e; \
	for branch in $(BRANCHES); do \
		TAG=$$(echo $$branch | sed 's/\//-/g')-$(GIT_TAG); \
		for arch in $(ARCHS); \
		do \
			docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME):$$TAG-$$arch; \
		done; \
	done
