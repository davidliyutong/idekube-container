# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IDEKube Container is a collection of Docker container images providing IDE environments (Coder, Jupyter, noVNC desktop) for Kubernetes clusters. Used in robotics, simulations, ML, and education contexts (SJTU SPEIT). All services are reverse-proxied by Nginx on port 80.

## Build System

The project uses `build.py` (a stateless CLI that reads `images.json`) to resolve the dependency DAG and run Docker build/push commands. The legacy Make + shell scripts are still available. Build arguments are read from `.dockerargs.base` or `.dockerargs.ascend` (selected per lineup in `images.json`), and env vars from `.env` (symlink to `.env.base` or `.env.ascend`). All Dockerfiles require BuildKit (`# syntax=docker/dockerfile:1`) — install scripts are bind-mounted per-RUN via `--mount=type=bind` instead of bulk-copied, so each layer's cache only depends on the single script it executes.

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

### Test Commands

Tests use Playwright + pytest, managed by `uv`. Assumes images are already built locally via `make build` / `make build_all`. Output goes to `.cache/test-output/` (report.html, screenshots, container logs) — covered by `.gitignore`.

```bash
# Install test deps (pytest, playwright, chromium) — also invoked as a dependency of test targets
make test_deps

# Test a single branch — follows the same BRANCH/LINEUP convention as `make build`
make test BRANCH=featured/base
make test BRANCH=jupyter/speit-ai LINEUP=ascend

# Test every branch in the base lineup (parallel workers = MAX_PARALLEL)
make test_all

# Test every branch in the ascend lineup
make test_all_ascend
```

The test system covers health endpoint, landing page, every service (vnc/coder/jupyter/terminal/agent), SSH proxy, access token auth (query/cookie/header), env var configs (init home, shell, UID, SSH keys, non-root), DinD (only `featured/dind`/`featured/kathara`), and GPU tests (skipped when no NVIDIA runtime). Unbuilt images and non-applicable tests are skipped automatically.

### QEMU Container Build (nested VM isolation)

Each `make` target depends on the previous one; running `make build_qemu` triggers the full chain automatically.

```bash
make prepare_qemu_files                    # Download UEFI firmware blobs + Ubuntu cloud images
make build_qemu_tools                      # Build cloud-localds and QEMU engine (Dockerfile.engine)
make build_qemu_root BRANCH=featured/base  # Provision root disk via Ansible inside a live VM
make build_qemu BRANCH=featured/base       # Build final QEMU Docker image embedding the disk
```

**Dependency chain:** `prepare_qemu_files` → `build_qemu_tools` → `build_qemu_root` → `build_qemu`

`build.py` uses stamp files (`.cache/…/.ready`, `.created`, `.root_ready`, `.image_ready`) so completed stages are skipped on re-runs.

### Image Tagging

Images are tagged as `$REGISTRY/$AUTHOR/$NAME:$BRANCH-$GIT_TAG-$ARCH`. The `BRANCH` value has `/` replaced with `-`. The git tag is auto-detected from `git tag --list --sort=-v:refname`.

## Architecture

### Four Flavors

- **`featured/`** — Full desktop with Coder + noVNC (TurboVNC + VirtualGL) + SSH. Variants: `base`, `speit`, `speit-ai`, `dind`, `kathara`, `ros2`
- **`coder/`** — Coder IDE only + SSH. Variants: `base`, `conda` (adds Miniconda)
- **`jupyter/`** — Jupyter only + SSH. Variants: `base`, `speit-ai`, `speit-ascendai`
- **`agent/`** — Standalone agent toolchain (Claude Code + opencode + document processing) exposing `/terminal` (ttyd web terminal) and `/ssh`. Variants: `base`, `openclaw` (adds openclaw gateway at `/agent`), `hermes` (adds Hermes Agent CLI + gateway API server + web dashboard at `/agent`)

### Directory Layout

- `manifests/docker/<flavor>/<variant>/Dockerfile` — Dockerfiles for each image variant
- `manifests/install-scripts/` — Modular shell scripts bind-mounted into Dockerfiles via `RUN --mount=type=bind` (e.g., `setup-packages.sh`, `setup-code-server.sh`, `setup-vnc.sh`)
- `artifacts/docker/<flavor>/rootfs/` — Root filesystem overlay copied into images (nginx configs, supervisord configs, skel files, landing pages)
- `artifacts/docker/<flavor>/rootfs/etc/idekube/health.json` — Per-flavor health check config (defines branch, entry URL, main service, and service ports)
- `artifacts/docker/rootfs/` — Common root filesystem overlay shared across all flavors (startup scripts, skel files, access-token nginx config, healthcheck supervisor config)
- `artifacts/docker/rootfs/startup.sh` — Main container entrypoint shared across flavors
- `artifacts/docker/rootfs/authn.sh` — Access-token authentication setup script called by `startup.sh`
- `tools/idekube-healthcheck/` — Go-based health check server (built via multi-stage Docker build, serves `/health` endpoint on port 9999)
- `scripts/shell/` — Build helper scripts (`build_image.sh`, `buildx_image.sh`, `docker_common.sh`, `build_qemu_root.sh`, etc.)
- `scripts/make/` — Makefile includes (`docker.mk`, `qemu.mk`)
- `manifests/qemu/Dockerfile` — Final QEMU container image (embeds provisioned root disk, UEFI firmware, and `startup.sh`/`run.sh`)
- `manifests/qemu/Dockerfile.engine` — QEMU engine image used during provisioning (`build_qemu_root`)
- `manifests/qemu/<flavor>/<variant>/install.yml` — Ansible playbook run inside the VM to install software and configure systemd services
- `artifacts/qemu/rootfs/` — Common VM rootfs overlay rsync'd into every QEMU branch (nginx access-token config, `vm-init.sh`, `idekube-healthcheck` binary extracted at build time, etc.)
- `artifacts/qemu/<flavor>/rootfs/` — Flavor-specific rootfs overlay applied on top of the common layer (e.g. `featured/rootfs/` adds nginx site config, `health.json`, XFCE skel, noVNC index)
- `artifacts/qemu/startup-scripts/` — Container-level entrypoint scripts (`startup.sh`, `run.sh`) COPY'd into the Docker images; not rsync'd into the VM
- `artifacts/qemu/configs/` — Cloud-init `user-data.yaml` and `meta-data.yaml` used during VM provisioning
- `.dockerargs.base` / `.dockerargs.ascend` — Build-arg files parsed line-by-line as `KEY=VALUE`

### Container Runtime

Containers run `supervisord` (via `tini`) to manage services. The entrypoint (`startup.sh`) handles:
1. Init container mode (`I_AM_INIT_CONTAINER`) — copies rootfs to external mount
2. Rootfs chroot mode (`/rootfs` mount) — binds host dirs and chroots
3. Normal mode — configures shell, home directory, SSH keys, configures nginx access-token auth (`authn.sh`), runs startup hooks from `/etc/idekube/startup.bash/*.sh`, then starts supervisord (which also launches the health check server on port 9999)

### Build Branches Order

Build order matters due to image dependencies. The build order is defined in `images.json` and resolved by `build.py`:
`featured/base featured/speit featured/speit-ai featured/dind featured/kathara featured/ros2 coder/base coder/conda jupyter/base jupyter/speit-ai agent/base agent/openclaw agent/hermes`

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
