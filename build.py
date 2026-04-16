#!/usr/bin/env python3
"""
IDEKube Container Build Orchestrator

Stateless CLI that reads images.json, resolves the dependency DAG,
and runs Docker build/push commands. Replaces the Make-based
dependency resolution and eliminates the need for symlink switching
between lineups.

Usage:
    python3 build.py <command> [args] [--lineup=base]

Docker commands:
    build <image>           Build single image (native arch)
    buildx <image>          Multi-arch build via buildx (no push)
    publishx <image>        Multi-arch build+push via buildx
    publish <image>         Push single-arch image to registry
    build-all               Build all images for a lineup (DAG order)
    buildx-all              Multi-arch build all images (DAG order)
    publishx-all            Multi-arch build+push all (DAG order)
    publish-all             Push all single-arch images (DAG order)

Manifest commands:
    manifest <image>        Create multi-arch manifest for one image
    manifest-all            Create manifests for all images in a lineup
    rmmanifest <image>      Remove per-arch tags for one image
    rmmanifest-all          Remove per-arch tags for all images in a lineup

QEMU commands:
    qemu-prepare            Download QEMU files and base cloud images
    qemu-build-tools        Build cloud-localds and QEMU engine images
    qemu-build-root <br>    Provision root disk via QEMU VM
    qemu-build <branch>     Build final QEMU Docker image
    qemu-publish <branch>   Push QEMU image to registry
    qemu-build-all          Full pipeline for all QEMU branches
    qemu-publish-all        Full pipeline + push for all QEMU branches

Info commands:
    ci-matrix               Output JSON for GitHub Actions fromJson()
    ci-matrix-native        Output JSON with archs for native per-arch CI
    qemu-ci-matrix          Output tier JSON for QEMU branches
    list                    List images for a lineup
    deps <image>            Show dependency chain for an image
"""

import argparse
import json
import os
import platform
import subprocess
import sys
from collections import deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

def load_config(config_path="images.json"):
    """Load and validate images.json."""
    path = Path(config_path)
    if not path.is_file():
        sys.exit(f"Error: config file not found: {config_path}")
    with open(path) as f:
        config = json.load(f)

    for key in ("defaults", "lineups", "images"):
        if key not in config:
            sys.exit(f"Error: missing top-level key '{key}' in {config_path}")

    return config


def get_lineup(config, lineup_name):
    """Return lineup config or exit with error."""
    lineups = config["lineups"]
    if lineup_name not in lineups:
        available = ", ".join(lineups.keys())
        sys.exit(f"Error: unknown lineup '{lineup_name}'. Available: {available}")
    return lineups[lineup_name]


def get_lineup_images(config, lineup_name):
    """Return the list of image names for a lineup."""
    return get_lineup(config, lineup_name)["images"]


def get_lineup_archs(config, lineup_name):
    """Return the arch list for a lineup, falling back to defaults.archs.

    A lineup may override `archs` when its base image is only valid on a subset
    of architectures (e.g. the Ascend CANN image is arm64-only). When a single
    arch is listed, buildx pushes under the plain tag with no `-<arch>` suffix.
    """
    lineup = get_lineup(config, lineup_name)
    return lineup.get("archs") or config["defaults"]["archs"]


def validate_lineup(config, lineup_name):
    """Validate that all images and their transitive deps are in the lineup."""
    lineup_images = set(get_lineup_images(config, lineup_name))
    all_images = config["images"]
    errors = []

    for image in lineup_images:
        if image not in all_images:
            errors.append(f"  '{image}' is in lineup '{lineup_name}' but not defined in images")
            continue
        dep = all_images[image].get("depends_on")
        visited = []
        while dep:
            visited.append(dep)
            if dep not in lineup_images:
                chain = " -> ".join([image] + visited)
                errors.append(
                    f"  '{image}' depends on '{dep}' which is not in lineup '{lineup_name}' "
                    f"(chain: {chain})"
                )
                break
            dep = all_images.get(dep, {}).get("depends_on")

    if errors:
        sys.exit(f"Error: lineup '{lineup_name}' has dependency issues:\n" + "\n".join(errors))


# ---------------------------------------------------------------------------
# Dockerargs parsing
# ---------------------------------------------------------------------------

def parse_dockerargs(filepath):
    """Parse a .dockerargs file (KEY=VALUE per line) into a dict."""
    args = {}
    path = Path(filepath)
    if not path.is_file():
        sys.exit(f"Error: dockerargs file not found: {filepath}")
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            args[key.strip()] = value.strip()
    return args


def dockerargs_to_build_flags(args):
    """Convert a dict of build args to Docker --build-arg flags."""
    flags = []
    for key, value in args.items():
        flags.extend(["--build-arg", f"{key}={value}"])
    return flags


# ---------------------------------------------------------------------------
# Environment detection
# ---------------------------------------------------------------------------

def detect_git_tag():
    """Detect latest git tag, fallback to 'latest'."""
    env_tag = os.environ.get("GIT_TAG")
    if env_tag:
        return env_tag
    try:
        result = subprocess.run(
            ["git", "tag", "--list", "--sort=-v:refname"],
            capture_output=True, text=True, check=True,
        )
        tags = result.stdout.strip().splitlines()
        return tags[0] if tags else "latest"
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "latest"


def detect_arch():
    """Detect native architecture, normalized to amd64/arm64."""
    machine = platform.machine()
    mapping = {"x86_64": "amd64", "aarch64": "arm64", "arm64": "arm64", "amd64": "amd64"}
    return mapping.get(machine, machine)


# ---------------------------------------------------------------------------
# Image reference computation
# ---------------------------------------------------------------------------

def branch_to_slug(branch):
    """Convert branch name to Docker tag slug: featured/base -> featured-base."""
    return branch.replace("/", "-")


def compute_refs(config, branch, lineup_name):
    """Compute image tag and full ref for a branch+lineup combination."""
    defaults = config["defaults"]
    registry = os.environ.get("REGISTRY", defaults["registry"])
    author = os.environ.get("AUTHOR", defaults["author"])
    name = os.environ.get("NAME", defaults["name"])
    git_tag = detect_git_tag()

    lineup = get_lineup(config, lineup_name)
    docker_args = parse_dockerargs(lineup["dockerargs_file"])
    tag_postfix = docker_args.get("TAG_POSTFIX", "")

    slug = branch_to_slug(branch)
    tag = f"{slug}-{git_tag}{tag_postfix}"
    latest_tag = f"{slug}-latest{tag_postfix}"
    image_ref = f"{registry}/{author}/{name}:{tag}"
    latest_ref = f"{registry}/{author}/{name}:{latest_tag}"

    return {
        "registry": registry,
        "author": author,
        "name": name,
        "git_tag": git_tag,
        "tag_postfix": tag_postfix,
        "slug": slug,
        "tag": tag,
        "latest_tag": latest_tag,
        "image_ref": image_ref,
        "latest_ref": latest_ref,
        "docker_args": docker_args,
    }


def get_full_build_args(refs):
    """Build the complete --build-arg flag list."""
    flags = dockerargs_to_build_flags(refs["docker_args"])
    flags.extend(["--build-arg", f"REGISTRY={refs['registry']}"])
    flags.extend(["--build-arg", f"AUTHOR={refs['author']}"])
    flags.extend(["--build-arg", f"NAME={refs['name']}"])
    flags.extend(["--build-arg", f"GIT_TAG={refs['git_tag']}"])
    return flags


# ---------------------------------------------------------------------------
# DAG operations
# ---------------------------------------------------------------------------

def topo_tiers(config, lineup_images):
    """
    Group lineup images into tiers using Kahn's algorithm.
    Tier 0 = roots (no deps or dep outside lineup), Tier 1 = depends on tier 0, etc.
    """
    all_images = config["images"]
    lineup_set = set(lineup_images)

    in_degree = {img: 0 for img in lineup_images}
    dependents = {img: [] for img in lineup_images}

    for img in lineup_images:
        dep = all_images[img].get("depends_on")
        if dep and dep in lineup_set:
            in_degree[img] += 1
            dependents[dep].append(img)

    tiers = []
    queue = deque([img for img in lineup_images if in_degree[img] == 0])

    while queue:
        tier = sorted(queue)
        tiers.append(tier)
        next_queue = deque()
        for img in tier:
            for child in dependents[img]:
                in_degree[child] -= 1
                if in_degree[child] == 0:
                    next_queue.append(child)
        queue = next_queue

    placed = sum(len(t) for t in tiers)
    if placed != len(lineup_images):
        sys.exit("Error: dependency cycle detected in lineup images")

    return tiers


def topo_tiers_generic(items, deps):
    """
    Generic tier computation for any item list + deps dict.
    deps maps item -> dependency (or None).
    """
    item_set = set(items)
    in_degree = {i: 0 for i in items}
    dependents = {i: [] for i in items}

    for item in items:
        dep = deps.get(item)
        if dep and dep in item_set:
            in_degree[item] += 1
            dependents[dep].append(item)

    tiers = []
    queue = deque([i for i in items if in_degree[i] == 0])

    while queue:
        tier = sorted(queue)
        tiers.append(tier)
        next_queue = deque()
        for i in tier:
            for child in dependents[i]:
                in_degree[child] -= 1
                if in_degree[child] == 0:
                    next_queue.append(child)
        queue = next_queue

    placed = sum(len(t) for t in tiers)
    if placed != len(items):
        sys.exit("Error: dependency cycle detected")

    return tiers


def get_dep_chain(config, image):
    """Return the full dependency chain for an image (root first)."""
    all_images = config["images"]
    if image not in all_images:
        sys.exit(f"Error: unknown image '{image}'")
    chain = [image]
    dep = all_images[image].get("depends_on")
    while dep:
        chain.append(dep)
        dep = all_images.get(dep, {}).get("depends_on")
    chain.reverse()
    return chain


# ---------------------------------------------------------------------------
# Docker command runners
# ---------------------------------------------------------------------------

def ensure_buildx_builder(dry_run=False):
    """Ensure the 'idekube' buildx builder exists."""
    try:
        result = subprocess.run(
            ["docker", "buildx", "ls"],
            capture_output=True, text=True, check=True,
        )
        if "idekube" in result.stdout:
            return
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass

    cmd = ["docker", "buildx", "create", "--name", "idekube", "--driver", "docker-container"]
    if dry_run:
        print(f"[dry-run] {' '.join(cmd)}")
    else:
        print(f"Creating buildx builder: {' '.join(cmd)}")
        subprocess.run(cmd, check=True)


def run_build(config, branch, lineup_name, dry_run=False, arch=None):
    """Build a single image for the specified (or native) architecture."""
    refs = compute_refs(config, branch, lineup_name)
    build_args = get_full_build_args(refs)
    arch = arch or detect_arch()
    dockerfile = f"{config['defaults']['dockerfile_base']}/{branch}/Dockerfile"

    cmd = [
        "docker", "build",
        *build_args,
        ".", "-t", f"{refs['image_ref']}-{arch}",
        "-t", refs["image_ref"],
        "-f", dockerfile,
    ]

    if dry_run:
        print(f"[dry-run] DOCKER_BUILDKIT=1 {' '.join(cmd)}")
        return

    env = {**os.environ, "DOCKER_BUILDKIT": "1"}
    print(f"Building {refs['image_ref']} ({arch})")
    subprocess.run(cmd, check=True, env=env)

    # Clean dangling images
    try:
        result = subprocess.run(
            ["docker", "images", "--filter", "dangling=true", "-q"],
            capture_output=True, text=True, check=True,
        )
        dangling = result.stdout.strip()
        if dangling:
            subprocess.run(
                ["docker", "rmi"] + dangling.splitlines(),
                check=False, capture_output=True,
            )
    except subprocess.CalledProcessError:
        pass


def run_buildx(config, branch, lineup_name, push=False, release=False, dry_run=False):
    """Multi-arch build (and optionally push) via buildx.

    Lineups can pin a subset of archs (e.g. ascend -> arm64-only). When a
    single arch is listed, --push writes a single-platform manifest under the
    plain tag, so no `-<arch>` suffix ever appears in the published tag.

    When release=True, the manifest is also pushed under `<slug>-latest<postfix>`
    so a floating "latest" alias tracks the most recent release.
    """
    refs = compute_refs(config, branch, lineup_name)
    build_args = get_full_build_args(refs)
    archs = get_lineup_archs(config, lineup_name)
    platforms = ",".join(f"linux/{a}" for a in archs)
    dockerfile = f"{config['defaults']['dockerfile_base']}/{branch}/Dockerfile"

    ensure_buildx_builder(dry_run=dry_run)

    cmd = [
        "docker", "buildx", "build",
        "--builder", "idekube",
        f"--platform={platforms}",
        *build_args,
    ]
    if push:
        cmd.append("--push")
    cmd.extend([".", "-t", refs["image_ref"], "-f", dockerfile])
    if release and push:
        cmd.extend(["-t", refs["latest_ref"]])

    if dry_run:
        action = "publishx" if push else "buildx"
        print(f"[dry-run] ({action}) {' '.join(cmd)}")
        return

    action = "Publishing" if push else "Building (multi-arch)"
    extra = f" (+ {refs['latest_ref']})" if release and push else ""
    print(f"{action} {refs['image_ref']}{extra}")
    subprocess.run(cmd, check=True)

    # For non-push buildx, also load per-arch images locally
    if not push:
        for arch in archs:
            load_cmd = [
                "docker", "buildx", "build",
                "--builder", "idekube",
                f"--platform=linux/{arch}",
                *build_args,
                "--load", ".",
                "-t", f"{refs['image_ref']}-{arch}",
                "-f", dockerfile,
            ]
            if dry_run:
                print(f"[dry-run] (load {arch}) {' '.join(load_cmd)}")
            else:
                print(f"Loading {refs['image_ref']}-{arch}")
                subprocess.run(load_cmd, check=True)


def run_publish(config, branch, lineup_name, dry_run=False, arch=None):
    """Push a single-arch image to the registry."""
    refs = compute_refs(config, branch, lineup_name)
    arch = arch or detect_arch()

    tag = f"{refs['image_ref']}-{arch}" if arch else refs["image_ref"]
    cmd = ["docker", "push", tag]

    if dry_run:
        print(f"[dry-run] {' '.join(cmd)}")
        return

    print(f"Pushing {tag}")
    subprocess.run(cmd, check=True)


# ---------------------------------------------------------------------------
# Manifest operations
# ---------------------------------------------------------------------------

def run_manifest(config, branch, lineup_name, release=False, dry_run=False):
    """Create a multi-arch manifest for one image.

    When release=True, additionally creates a <latest_ref> manifest referencing
    the same per-arch tags so a floating "latest" alias tracks this release.
    """
    refs = compute_refs(config, branch, lineup_name)
    archs = get_lineup_archs(config, lineup_name)
    ref = refs["image_ref"]
    arch_refs = [f"{ref}-{a}" for a in archs]

    targets = [ref]
    if release:
        targets.append(refs["latest_ref"])

    for target in targets:
        cmds = [
            (["docker", "manifest", "rm", target], True),       # ignore errors
            (["docker", "manifest", "create", target, *arch_refs], False),
        ]
        for a in archs:
            cmds.append((
                ["docker", "manifest", "annotate", "--os", "linux", "--arch", a, target, f"{ref}-{a}"],
                False,
            ))
        cmds.append((["docker", "manifest", "push", target], False))

        for cmd, ignore_error in cmds:
            if dry_run:
                prefix = "[dry-run] " + ("(ignore-error) " if ignore_error else "")
                print(f"{prefix}{' '.join(cmd)}")
            else:
                subprocess.run(cmd, check=not ignore_error,
                               capture_output=ignore_error)


def run_rmmanifest(config, branch, lineup_name, dry_run=False):
    """Remove per-arch tags for one image from the registry."""
    refs = compute_refs(config, branch, lineup_name)
    archs = get_lineup_archs(config, lineup_name)

    for a in archs:
        tag = f"{refs['image_ref']}-{a}"
        cmd = ["hub-tool", "tag", "rm", tag]
        if dry_run:
            print(f"[dry-run] (ignore-error) {' '.join(cmd)}")
        else:
            subprocess.run(cmd, check=False)


def run_manifest_all(config, lineup_name, release=False, dry_run=False):
    """Create multi-arch manifests for all images in a lineup."""
    images = get_lineup_images(config, lineup_name)
    for image in images:
        run_manifest(config, image, lineup_name, release=release, dry_run=dry_run)


def run_rmmanifest_all(config, lineup_name, dry_run=False):
    """Remove per-arch tags for all images in a lineup."""
    images = get_lineup_images(config, lineup_name)
    for image in images:
        run_rmmanifest(config, image, lineup_name, dry_run=dry_run)


# ---------------------------------------------------------------------------
# QEMU operations
# ---------------------------------------------------------------------------

def get_qemu_config(config):
    """Return the QEMU config section or exit with error."""
    qemu = config.get("qemu")
    if not qemu:
        sys.exit("Error: no 'qemu' section in images.json")
    return qemu


def qemu_topo_tiers(config):
    """Compute tiers for QEMU branches from their dependency graph."""
    qemu = get_qemu_config(config)
    branches = qemu["branches"]
    deps = qemu.get("deps", {})
    return topo_tiers_generic(branches, deps)


def qemu_prepare(config, dry_run=False):
    """Download QEMU files and base cloud images (stages 1-2)."""
    stamp_files = Path(".cache/qemu_files/.ready")
    if stamp_files.exists():
        print("QEMU files already prepared (stamp exists), skipping")
    else:
        cmd = ["bash", "scripts/shell/prepare_qemu_files.sh"]
        if dry_run:
            print(f"[dry-run] {' '.join(cmd)}")
        else:
            subprocess.run(cmd, check=True)

    stamp_images = Path(".cache/qemu_images/artifacts/empty")
    if stamp_images.exists():
        print("QEMU base images already prepared (stamp exists), skipping")
    else:
        cmd = ["bash", "scripts/shell/prepare_qemu_images.sh"]
        if dry_run:
            print(f"[dry-run] {' '.join(cmd)}")
        else:
            subprocess.run(cmd, check=True)


def qemu_build_tools(config, dry_run=False):
    """Build cloud-localds and QEMU engine Docker images (stages 3-4)."""
    # cloud-localds
    stamp_tools = Path(".cache/qemu_images/cloud-localds.created")
    if stamp_tools.exists():
        print("cloud-localds already built (stamp exists), skipping")
    else:
        cmd = ["docker", "build", "-t", "cloud-localds:latest",
               "-f", "tools/utility/cloud-localds/Dockerfile", "."]
        if dry_run:
            print(f"[dry-run] {' '.join(cmd)}")
        else:
            print("Building cloud-localds")
            subprocess.run(cmd, check=True)
            stamp_tools.parent.mkdir(parents=True, exist_ok=True)
            stamp_tools.touch()

    # QEMU engine
    stamp_engine = Path(".cache/qemu_images/idekube-qemu-engine.created")
    if stamp_engine.exists():
        print("QEMU engine already built (stamp exists), skipping")
    else:
        cmd = ["docker", "build",
               "--build-arg", "ROOT_DISK_IMAGE_DIR=.cache/qemu_images/artifacts/empty",
               "-t", "idekube-qemu-engine:latest",
               "-f", "manifests/qemu/Dockerfile.engine", "."]
        if dry_run:
            print(f"[dry-run] {' '.join(cmd)}")
        else:
            print("Building QEMU engine")
            subprocess.run(cmd, check=True)
            stamp_engine.parent.mkdir(parents=True, exist_ok=True)
            stamp_engine.touch()


def qemu_build_root(config, branch, dry_run=False):
    """Provision root disk via QEMU VM (stage 5). Delegates to shell script."""
    stamp = Path(f".cache/{branch}/.root_ready")
    if stamp.exists():
        print(f"Root disk for {branch} already built (stamp exists), skipping")
        return

    cmd = ["bash", "scripts/shell/build_qemu_root.sh"]
    if dry_run:
        print(f"[dry-run] BRANCH={branch} {' '.join(cmd)}")
        return

    print(f"Building root disk for {branch} (this may take 20-60 minutes)")
    env = {**os.environ, "BRANCH": branch}
    subprocess.run(cmd, check=True, env=env)


def qemu_build(config, branch, dry_run=False):
    """Build final QEMU Docker image (stage 6). Delegates to shell script."""
    stamp = Path(f".cache/{branch}/.image_ready")
    if stamp.exists():
        print(f"QEMU image for {branch} already built (stamp exists), skipping")
        return

    cmd = ["bash", "scripts/shell/build_qemu.sh"]
    if dry_run:
        print(f"[dry-run] BRANCH={branch} {' '.join(cmd)}")
        return

    print(f"Building QEMU image for {branch}")
    env = {**os.environ, "BRANCH": branch}
    subprocess.run(cmd, check=True, env=env)


def qemu_publish(config, branch, dry_run=False):
    """Push QEMU image to registry (stage 7). Delegates to shell script."""
    cmd = ["bash", "scripts/shell/publish_qemu.sh"]
    if dry_run:
        print(f"[dry-run] BRANCH={branch} {' '.join(cmd)}")
        return

    print(f"Publishing QEMU image for {branch}")
    env = {**os.environ, "BRANCH": branch}
    subprocess.run(cmd, check=True, env=env)


def qemu_build_all(config, publish=False, dry_run=False):
    """Run the full QEMU pipeline for all branches, respecting deps."""
    # Shared preparation stages
    print("=== QEMU: Preparing files and images ===")
    qemu_prepare(config, dry_run=dry_run)

    print("\n=== QEMU: Building tools ===")
    qemu_build_tools(config, dry_run=dry_run)

    # Per-branch stages in DAG order
    tiers = qemu_topo_tiers(config)
    for tier_idx, tier_branches in enumerate(tiers):
        for branch in tier_branches:
            print(f"\n=== QEMU Tier {tier_idx}: {branch} ===")
            qemu_build_root(config, branch, dry_run=dry_run)
            qemu_build(config, branch, dry_run=dry_run)
            if publish:
                qemu_publish(config, branch, dry_run=dry_run)


# ---------------------------------------------------------------------------
# Batch operations
# ---------------------------------------------------------------------------

def run_batch(config, lineup_name, action_fn, parallel=2, continue_on_error=False, dry_run=False):
    """Execute an action for all images in a lineup, respecting the DAG."""
    lineup_images = get_lineup_images(config, lineup_name)
    validate_lineup(config, lineup_name)
    tiers = topo_tiers(config, lineup_images)

    failed = []
    for tier_idx, tier_images in enumerate(tiers):
        print(f"\n{'='*60}")
        print(f"Tier {tier_idx}: {', '.join(tier_images)}")
        print(f"{'='*60}")

        if parallel <= 1 or len(tier_images) == 1:
            for image in tier_images:
                try:
                    action_fn(config, image, lineup_name, dry_run=dry_run)
                except (subprocess.CalledProcessError, Exception) as e:
                    if continue_on_error:
                        print(f"WARNING: {image} failed: {e}")
                        failed.append(image)
                    else:
                        raise
        else:
            with ThreadPoolExecutor(max_workers=parallel) as pool:
                futures = {
                    pool.submit(action_fn, config, img, lineup_name, dry_run): img
                    for img in tier_images
                }
                for future in as_completed(futures):
                    img = futures[future]
                    try:
                        future.result()
                    except Exception as e:
                        if continue_on_error:
                            print(f"WARNING: {img} failed: {e}")
                            failed.append(img)
                        else:
                            raise

    if failed:
        print(f"\nFailed images: {', '.join(failed)}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# CI matrix generation
# ---------------------------------------------------------------------------

def ci_matrix(config, lineup_name):
    """Generate JSON matrix for GitHub Actions fromJson()."""
    lineup_images = get_lineup_images(config, lineup_name)
    validate_lineup(config, lineup_name)
    tiers = topo_tiers(config, lineup_images)

    result = {"lineup": lineup_name}
    for i, tier in enumerate(tiers):
        result[f"tier{i}"] = tier

    return result


def ci_matrix_native(config, lineup_name):
    """Generate JSON matrix with archs for native per-arch CI strategy."""
    lineup_images = get_lineup_images(config, lineup_name)
    validate_lineup(config, lineup_name)
    tiers = topo_tiers(config, lineup_images)

    result = {
        "lineup": lineup_name,
        "archs": get_lineup_archs(config, lineup_name),
    }
    for i, tier in enumerate(tiers):
        result[f"tier{i}"] = tier

    return result


def qemu_ci_matrix(config):
    """Generate JSON matrix for QEMU branches."""
    tiers = qemu_topo_tiers(config)
    result = {}
    for i, tier in enumerate(tiers):
        result[f"tier{i}"] = tier
    return result


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    # Common flags shared across all subcommands
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--config", default="images.json", help="Path to images.json")
    common.add_argument("--lineup", default="base", help="Lineup name (default: base)")

    parser = argparse.ArgumentParser(
        description="IDEKube Container Build Orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # --- Docker single-image commands ---
    for cmd_name in ("build", "publish"):
        p = sub.add_parser(cmd_name, parents=[common], help=f"{cmd_name} a single image")
        p.add_argument("image", help="Image name (e.g., featured/base)")
        p.add_argument("--arch", help="Override architecture (amd64, arm64)")
        p.add_argument("--dry-run", action="store_true", help="Print commands without executing")

    for cmd_name in ("buildx", "publishx"):
        p = sub.add_parser(cmd_name, parents=[common], help=f"{cmd_name} a single image")
        p.add_argument("image", help="Image name (e.g., featured/base)")
        p.add_argument("--dry-run", action="store_true", help="Print commands without executing")
        if cmd_name == "publishx":
            p.add_argument("--release", action="store_true",
                           help="Also push as <branch>-latest[-postfix] alongside the versioned tag")

    # --- Docker batch commands ---
    for cmd_name in ("build-all", "buildx-all", "publishx-all", "publish-all"):
        p = sub.add_parser(cmd_name, parents=[common], help=f"{cmd_name} for a lineup")
        p.add_argument("--parallel", type=int, default=2, help="Max parallel builds per tier")
        p.add_argument("--continue-on-error", action="store_true", help="Continue on failures")
        p.add_argument("--dry-run", action="store_true", help="Print commands without executing")
        if cmd_name in ("build-all", "publish-all"):
            p.add_argument("--arch", help="Override architecture (amd64, arm64)")
        if cmd_name == "publishx-all":
            p.add_argument("--release", action="store_true",
                           help="Also push as <branch>-latest[-postfix] alongside the versioned tag")

    # --- Manifest commands ---
    for cmd_name in ("manifest", "rmmanifest"):
        p = sub.add_parser(cmd_name, parents=[common], help=f"{cmd_name} for a single image")
        p.add_argument("image", help="Image name (e.g., featured/base)")
        p.add_argument("--dry-run", action="store_true", help="Print commands without executing")
        if cmd_name == "manifest":
            p.add_argument("--release", action="store_true",
                           help="Also push <branch>-latest[-postfix] manifest")

    for cmd_name in ("manifest-all", "rmmanifest-all"):
        p = sub.add_parser(cmd_name, parents=[common], help=f"{cmd_name} for a lineup")
        p.add_argument("--dry-run", action="store_true", help="Print commands without executing")
        if cmd_name == "manifest-all":
            p.add_argument("--release", action="store_true",
                           help="Also push <branch>-latest[-postfix] manifests")

    # --- QEMU commands ---
    for cmd_name in ("qemu-prepare", "qemu-build-tools"):
        p = sub.add_parser(cmd_name, parents=[common], help=cmd_name)
        p.add_argument("--dry-run", action="store_true", help="Print commands without executing")

    for cmd_name in ("qemu-build-root", "qemu-build", "qemu-publish"):
        p = sub.add_parser(cmd_name, parents=[common], help=cmd_name)
        p.add_argument("branch", help="QEMU branch (e.g., featured/base)")
        p.add_argument("--dry-run", action="store_true", help="Print commands without executing")

    for cmd_name in ("qemu-build-all", "qemu-publish-all"):
        p = sub.add_parser(cmd_name, parents=[common], help=cmd_name)
        p.add_argument("--dry-run", action="store_true", help="Print commands without executing")

    # --- Info commands ---
    p_matrix = sub.add_parser("ci-matrix", parents=[common], help="Output GitHub Actions matrix JSON")
    p_matrix.add_argument("--pretty", action="store_true", help="Pretty-print JSON")

    p_matrix_native = sub.add_parser("ci-matrix-native", parents=[common],
                                     help="Output matrix JSON with archs for native per-arch CI")
    p_matrix_native.add_argument("--pretty", action="store_true", help="Pretty-print JSON")

    p_qemu_matrix = sub.add_parser("qemu-ci-matrix", parents=[common],
                                   help="Output tier JSON for QEMU branches")
    p_qemu_matrix.add_argument("--pretty", action="store_true", help="Pretty-print JSON")

    sub.add_parser("list", parents=[common], help="List images for a lineup")

    p_deps = sub.add_parser("deps", parents=[common], help="Show dependency chain")
    p_deps.add_argument("image", help="Image name")

    args = parser.parse_args()
    config = load_config(args.config)

    # --- Dispatch ---

    # Docker single-image
    if args.command == "build":
        _validate_image_in_lineup(config, args.image, args.lineup)
        run_build(config, args.image, args.lineup, dry_run=args.dry_run, arch=args.arch)

    elif args.command == "buildx":
        _validate_image_in_lineup(config, args.image, args.lineup)
        run_buildx(config, args.image, args.lineup, push=False, dry_run=args.dry_run)

    elif args.command == "publishx":
        _validate_image_in_lineup(config, args.image, args.lineup)
        run_buildx(config, args.image, args.lineup, push=True,
                   release=args.release, dry_run=args.dry_run)

    elif args.command == "publish":
        _validate_image_in_lineup(config, args.image, args.lineup)
        run_publish(config, args.image, args.lineup, dry_run=args.dry_run, arch=args.arch)

    # Docker batch
    elif args.command == "build-all":
        arch = getattr(args, "arch", None)
        run_batch(config, args.lineup,
                  lambda c, i, l, dry_run=False: run_build(c, i, l, dry_run=dry_run, arch=arch),
                  parallel=args.parallel, continue_on_error=args.continue_on_error,
                  dry_run=args.dry_run)

    elif args.command == "buildx-all":
        run_batch(config, args.lineup,
                  lambda c, i, l, dry_run=False: run_buildx(c, i, l, push=False, dry_run=dry_run),
                  parallel=args.parallel, continue_on_error=args.continue_on_error,
                  dry_run=args.dry_run)

    elif args.command == "publishx-all":
        release = args.release
        run_batch(config, args.lineup,
                  lambda c, i, l, dry_run=False: run_buildx(c, i, l, push=True,
                                                             release=release, dry_run=dry_run),
                  parallel=args.parallel, continue_on_error=args.continue_on_error,
                  dry_run=args.dry_run)

    elif args.command == "publish-all":
        arch = getattr(args, "arch", None)
        run_batch(config, args.lineup,
                  lambda c, i, l, dry_run=False: run_publish(c, i, l, dry_run=dry_run, arch=arch),
                  parallel=args.parallel, continue_on_error=args.continue_on_error,
                  dry_run=args.dry_run)

    # Manifest
    elif args.command == "manifest":
        _validate_image_in_lineup(config, args.image, args.lineup)
        run_manifest(config, args.image, args.lineup,
                     release=args.release, dry_run=args.dry_run)

    elif args.command == "manifest-all":
        run_manifest_all(config, args.lineup,
                         release=args.release, dry_run=args.dry_run)

    elif args.command == "rmmanifest":
        _validate_image_in_lineup(config, args.image, args.lineup)
        run_rmmanifest(config, args.image, args.lineup, dry_run=args.dry_run)

    elif args.command == "rmmanifest-all":
        run_rmmanifest_all(config, args.lineup, dry_run=args.dry_run)

    # QEMU
    elif args.command == "qemu-prepare":
        qemu_prepare(config, dry_run=args.dry_run)

    elif args.command == "qemu-build-tools":
        qemu_build_tools(config, dry_run=args.dry_run)

    elif args.command == "qemu-build-root":
        qemu_build_root(config, args.branch, dry_run=args.dry_run)

    elif args.command == "qemu-build":
        qemu_build(config, args.branch, dry_run=args.dry_run)

    elif args.command == "qemu-publish":
        qemu_publish(config, args.branch, dry_run=args.dry_run)

    elif args.command == "qemu-build-all":
        qemu_build_all(config, publish=False, dry_run=args.dry_run)

    elif args.command == "qemu-publish-all":
        qemu_build_all(config, publish=True, dry_run=args.dry_run)

    # Info
    elif args.command == "ci-matrix":
        result = ci_matrix(config, args.lineup)
        indent = 2 if args.pretty else None
        print(json.dumps(result, indent=indent))

    elif args.command == "ci-matrix-native":
        result = ci_matrix_native(config, args.lineup)
        indent = 2 if args.pretty else None
        print(json.dumps(result, indent=indent))

    elif args.command == "qemu-ci-matrix":
        result = qemu_ci_matrix(config)
        indent = 2 if args.pretty else None
        print(json.dumps(result, indent=indent))

    elif args.command == "list":
        images = get_lineup_images(config, args.lineup)
        tiers = topo_tiers(config, images)
        for i, tier in enumerate(tiers):
            print(f"Tier {i}: {', '.join(tier)}")

    elif args.command == "deps":
        chain = get_dep_chain(config, args.image)
        print(" -> ".join(chain))


def _validate_image_in_lineup(config, image, lineup_name):
    """Validate that an image exists and belongs to the given lineup."""
    if image not in config["images"]:
        sys.exit(f"Error: unknown image '{image}'")
    lineup_images = get_lineup_images(config, lineup_name)
    if image not in lineup_images:
        sys.exit(f"Error: '{image}' is not in lineup '{lineup_name}'")


if __name__ == "__main__":
    main()
