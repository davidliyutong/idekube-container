ROOT_DISK_IMAGE_DIR := third_party/qemu_images/artifacts
prepare_qemu_files:
	scripts/shell/prepare_qemu_files.sh

third_party/qemu_files/.ready:
	scripts/shell/prepare_qemu_files.sh
	touch third_party/qemu_files/.ready

prepare_qemu_images:
	scripts/shell/prepare_qemu_images.sh

third_party/qemu_images/artifacts/empty:
	scripts/shell/prepare_qemu_images.sh
	mkdir -p third_party/qemu_images/artifacts/empty

build_qemu_engine: pull_deps third_party/qemu_images/artifacts/empty
	@mkdir -p third_party/qemu_images/artifacts/empty
	@docker build --build-arg ROOT_DISK_IMAGE_DIR="third_party/qemu_images/artifacts/empty" -t idekube-qemu-engine:latest -f manifests/qemu/Dockerfile.engine .

build_qemu: pull_deps third_party/qemu_images/artifacts/empty
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/build_qemu.sh

build_qemu_root: build_qemu_engine
	@export REGISTRY=${REGISTRY} AUTHOR=${AUTHOR} NAME=${NAME} BRANCH=${BRANCH}; bash scripts/shell/build_qemu_root.sh

debug_qemu_root:
	echo "Starting QEMU VM natively for branch ${BRANCH}..."
	@cd .cache/${BRANCH}/ && ../../../artifacts/qemu/startup-scripts/run.sh