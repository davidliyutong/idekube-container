# Reuse idekube-qemu-engine as the base: it already ships the pinned QEMU
# build, cloud-localds, UEFI blobs, cloud-init templates, and /run.sh +
# /startup.sh from artifacts/qemu/startup-scripts/. This image only layers
# the provisioned root disk on top and flips the entrypoint from the engine's
# debug shell to /startup.sh.
ARG ENGINE_IMAGE=idekube-qemu-engine:latest
FROM ${ENGINE_IMAGE} AS runtime

ARG ROOT_DISK_IMAGE_DIR=""
WORKDIR /var/lib/idekube/
COPY ${ROOT_DISK_IMAGE_DIR} ./images/

WORKDIR /var/lib/data
ENTRYPOINT [ "/startup.sh" ]
