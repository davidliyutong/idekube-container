# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IDEKube Container is a collection of Docker container images providing IDE environments (Coder, Jupyter, noVNC desktop) for Kubernetes clusters. Used in robotics, simulations, ML, and education contexts (SJTU SPEIT). All services are reverse-proxied by Nginx on port 80.

## Build System

The project uses Make + shell scripts. Build arguments are read from `.dockerargs` (a symlink to `.dockerargs.base` or `.dockerargs.ascend`), and env vars from `.env` (symlink to `.env.base` or `.env.ascend`). All Dockerfiles require BuildKit (`# syntax=docker/dockerfile:1`) — install scripts are bind-mounted per-RUN via `--mount=type=bind` instead of bulk-copied, so each layer's cache only depends on the single script it executes.

### Key Build Commands

```bash
# Build a single branch for the local architecture
make build BRANCH=featured/base

# Build all branches sequentially
make build_all

# Multi-arch build via docker buildx
make buildx BRANCH=featured/base
make buildx_all

# Publish (push) multi-arch images
make publishx BRANCH=featured/base
make publishx_all

# Run locally for testing
make dev.run BRANCH=featured/base

# Build and run
make debug BRANCH=featured/base

# Switch build type (base vs Ascend AI accelerator)
make set_type TYPE=base
make set_type TYPE=ascend
```

### QEMU Container Build (nested VM isolation)

```bash
make prepare_qemu_files       # Download QEMU sources
make prepare_qemu_images      # Prepare base images
make build_qemu_tools         # Build cloud-localds tool
make build_qemu_engine        # Build QEMU engine image
make build_qemu_root BRANCH=featured/base  # Build root disk
make build_qemu BRANCH=featured/base       # Build final QEMU container
```

### Image Tagging

Images are tagged as `$REGISTRY/$AUTHOR/$NAME:$BRANCH-$GIT_TAG-$ARCH`. The `BRANCH` value has `/` replaced with `-`. The git tag is auto-detected from `git tag --list --sort=-v:refname`.

## Architecture

### Four Flavors

- **`featured/`** — Full desktop with Coder + noVNC (TurboVNC + VirtualGL) + SSH. Variants: `base`, `speit`, `speit-ai`, `dind`, `ros2`
- **`coder/`** — Coder IDE only + SSH. Variants: `base`, `lite`
- **`jupyter/`** — Jupyter only + SSH. Variants: `base`, `speit-ai`, `speit-ascendai`
- **`agent/`** — Standalone agent toolchain (openclaw + Claude Code + opencode + document processing) exposing `/agent`, `/terminal` (ttyd web terminal), and `/ssh`. Variants: `base`

### Directory Layout

- `manifests/docker/<flavor>/<variant>/Dockerfile` — Dockerfiles for each image variant
- `manifests/install-scripts/` — Modular shell scripts bind-mounted into Dockerfiles via `RUN --mount=type=bind` (e.g., `setup-packages.sh`, `setup-code-server.sh`, `setup-vnc.sh`)
- `artifacts/docker/<flavor>/rootfs/` — Root filesystem overlay copied into images (nginx configs, supervisord configs, skel files, landing pages)
- `artifacts/docker/<flavor>/rootfs/etc/nginx/conf.d/access_token.conf` — Nginx map template for access-token auth (placeholder replaced at runtime by `authn.sh`)
- `artifacts/docker/startup-scripts/startup.sh` — Main container entrypoint shared across flavors
- `artifacts/docker/startup-scripts/authn.sh` — Access-token authentication setup script called by `startup.sh`
- `scripts/shell/` — Build helper scripts (`build_image.sh`, `buildx_image.sh`, `docker_common.sh`, etc.)
- `scripts/make/` — Makefile includes (`docker.mk`, `qemu.mk`)
- `manifests/qemu/` — Dockerfiles for QEMU-based nested VM containers
- `artifacts/qemu/` — QEMU configs and startup scripts
- `.dockerargs.base` / `.dockerargs.ascend` — Build-arg files parsed line-by-line as `KEY=VALUE`

### Container Runtime

Containers run `supervisord` (via `tini`) to manage services. The entrypoint (`startup.sh`) handles:
1. Init container mode (`I_AM_INIT_CONTAINER`) — copies rootfs to external mount
2. Rootfs chroot mode (`/rootfs` mount) — binds host dirs and chroots
3. Normal mode — configures shell, home directory, SSH keys, configures nginx access-token auth (`authn.sh`), runs startup hooks from `/etc/idekube/startup.bash/*.sh`, then starts supervisord

### Build Branches Order

Build order matters due to image dependencies. The `BRANCHES` variable in the Makefile defines this:
`featured/base featured/speit featured/speit-ai featured/dind coder/base coder/lite jupyter/base jupyter/speit-ai agent/base`

### CI/CD

- GitHub Actions workflows in `.github/workflows/` handle multi-arch builds and publishing
- GitLab CI in `.gitlab-ci.yml` for on-premise builds (manual trigger)

## Environment Variables (Runtime)

| Variable | Purpose |
|---|---|
| `IDEKUBE_INIT_HOME` | Set to any value to initialize home from `/etc/skel` |
| `IDEKUBE_PREFERED_SHELL` | Path to preferred shell (default: `/bin/bash`) |
| `IDEKUBE_USER_UID` | Override the UID of the container user |
| `IDEKUBE_AUTHORIZED_KEYS` | Base64-encoded SSH authorized keys |
| `IDEKUBE_ACCESS_TOKEN` | Optional access token for nginx-level web auth (excludes `/ssh`). Accepts token via query param `idekube-container-access-token`, cookie `idekube_container_access_token`, or header `X-IDEKUBE-Container-Access-Token` |
| `I_AM_INIT_CONTAINER` | Triggers init container mode |
