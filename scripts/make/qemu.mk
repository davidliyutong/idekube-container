ROOT_DISK_IMAGE_DIR := .cache/qemu_images/artifacts

ENGINE_MARKER := .cache/qemu_images/idekube-qemu-engine.created
TOOLS_MARKER := .cache/qemu_images/cloud-localds.created

prepare_qemu_files: .cache/qemu_files/.ready

.cache/qemu_files/.ready:
	scripts/shell/prepare_qemu_files.sh
	touch .cache/qemu_files/.ready

prepare_qemu_images: .cache/qemu_images/artifacts/empty prepare_qemu_files

.cache/qemu_images/artifacts/empty:
	scripts/shell/prepare_qemu_images.sh && mkdir -p .cache/qemu_images/artifacts/empty

build_qemu_tools: $(TOOLS_MARKER)
$(TOOLS_MARKER): .cache/qemu_files/.ready tools/utility/cloud-localds/Dockerfile
	@docker build -t cloud-localds:latest -f tools/utility/cloud-localds/Dockerfile .
	@mkdir -p $(dir $@) && touch $@

build_qemu_engine: $(ENGINE_MARKER)
$(ENGINE_MARKER): .cache/qemu_images/artifacts/empty .cache/qemu_files/.ready manifests/qemu/Dockerfile.engine
	@docker build --build-arg ROOT_DISK_IMAGE_DIR=".cache/qemu_images/artifacts/empty" -t idekube-qemu-engine:latest -f manifests/qemu/Dockerfile.engine .
	@mkdir -p $(dir $@) && touch $@

build_qemu_root: .cache/${BRANCH}/.root_ready
.cache/${BRANCH}/.root_ready: $(ENGINE_MARKER) $(TOOLS_MARKER)
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/build_qemu_root.sh
	@mkdir -p $(dir $@) && touch $@

build_qemu: .cache/${BRANCH}/.image_ready

.cache/${BRANCH}/.image_ready: .cache/${BRANCH}/.root_ready
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/build_qemu.sh
	@touch $@

publish_qemu: build_qemu
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/publish_qemu.sh

manifest_qemu:
	@set -e; \
	docker manifest rm $(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG) || true;
	docker manifest create $(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG) $(IMAGES_QEMU);
	for arch in $(ARCHS); \
	do \
		echo docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG) $(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG)-$$arch; \
		docker manifest annotate --os linux --arch $$arch $(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG) $(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG)-$$arch; \
	done
	docker manifest push $(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG)

rmmanifest_qemu:
	@set -e; \
	for arch in $(ARCHS); \
	do \
		hub-tool tag rm $(REGISTRY)/$(AUTHOR)/$(NAME)-qemu:$(TAG)-$$arch || true; \
	done


debug_qemu_root:
	echo "Starting QEMU VM natively for branch ${BRANCH}..."
	@cd .cache/${BRANCH}/ && ../../../artifacts/qemu/startup-scripts/run.sh