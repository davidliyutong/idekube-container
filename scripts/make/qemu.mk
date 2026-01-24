ROOT_DISK_IMAGE_DIR := .cache/qemu_images/artifacts

prepare_qemu_files: .cache/qemu_files/.ready

.cache/qemu_files/.ready:
	scripts/shell/prepare_qemu_files.sh
	touch .cache/qemu_files/.ready

prepare_qemu_images: .cache/qemu_images/artifacts/empty prepare_qemu_files

.cache/qemu_images/artifacts/empty:
	scripts/shell/prepare_qemu_images.sh && mkdir -p .cache/qemu_images/artifacts/empty

build_qemu_tools: prepare_qemu_files
	@docker build -t cloud-localds:latest -f tools/utility/cloud-localds/Dockerfile .

build_qemu_engine: prepare_qemu_images
	@docker build --build-arg ROOT_DISK_IMAGE_DIR=".cache/qemu_images/artifacts/empty" -t idekube-qemu-engine:latest -f manifests/qemu/Dockerfile.engine .

build_qemu: prepare_qemu_images
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/build_qemu.sh

build_qemu_root: build_qemu_engine build_qemu_tools
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/build_qemu_root.sh

debug_qemu_root:
	echo "Starting QEMU VM natively for branch ${BRANCH}..."
	@cd .cache/${BRANCH}/ && ../../../artifacts/qemu/startup-scripts/run.sh