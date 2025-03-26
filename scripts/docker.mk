
build: pull_deps
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH} TAG=${TAG}; bash scripts/build_image.sh

buildx: pull_deps
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH} TAG=${TAG}; bash scripts/buildx_image.sh

publish: build
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH} TAG=${TAG}; bash scripts/publish_image.sh

publishx: pull_deps
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH} TAG=${TAG}; bash scripts/publishx_image.sh

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
	
rmmanifest:
	@set -e; \
	for arch in $(ARCHS); \
	do \
		docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME):$(TAG)-$$arch; \
	done
