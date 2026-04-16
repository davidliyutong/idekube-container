"""Image tag resolution and availability detection.

Mirrors the logic in build.py to compute image references for locally-built images.
"""

from __future__ import annotations

import json
import os
import platform
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
IMAGES_JSON = PROJECT_ROOT / "images.json"


def _load_config() -> dict:
    with open(IMAGES_JSON) as f:
        return json.load(f)


def _parse_dockerargs(filename: str) -> dict[str, str]:
    """Parse a .dockerargs file into a dict (same logic as build.py)."""
    path = PROJECT_ROOT / filename
    result: dict[str, str] = {}
    if not path.exists():
        return result
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, _, value = line.partition("=")
            result[key.strip()] = value.strip()
    return result


def detect_git_tag() -> str:
    env_tag = os.environ.get("GIT_TAG")
    if env_tag:
        return env_tag
    try:
        result = subprocess.run(
            ["git", "tag", "--list", "--sort=-v:refname"],
            capture_output=True,
            text=True,
            check=True,
            cwd=PROJECT_ROOT,
        )
        tags = result.stdout.strip().splitlines()
        return tags[0] if tags else "latest"
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "latest"


def detect_arch() -> str:
    machine = platform.machine()
    mapping = {
        "x86_64": "amd64",
        "aarch64": "arm64",
        "arm64": "arm64",
        "amd64": "amd64",
    }
    return mapping.get(machine, machine)


def get_lineup_branches(lineup: str) -> list[str]:
    config = _load_config()
    lineup_cfg = config["lineups"].get(lineup)
    if not lineup_cfg:
        raise ValueError(f"Unknown lineup: {lineup}")
    return lineup_cfg["images"]


def get_lineup_dockerargs_file(lineup: str) -> str:
    config = _load_config()
    return config["lineups"][lineup]["dockerargs_file"]


def branch_to_slug(branch: str) -> str:
    return branch.replace("/", "-")


def resolve_image_ref(branch: str, lineup: str = "base") -> str:
    """Compute the full image reference for a locally-built image.

    Local `make build` tags images as both:
      {registry}/{author}/{name}:{slug}-{git_tag}{tag_postfix}-{arch}
      {registry}/{author}/{name}:{slug}-{git_tag}{tag_postfix}
    We use the arch-less tag for consistency.
    """
    config = _load_config()
    defaults = config["defaults"]
    registry = os.environ.get("REGISTRY", defaults["registry"])
    author = os.environ.get("AUTHOR", defaults["author"])
    name = os.environ.get("NAME", defaults["name"])
    git_tag = detect_git_tag()

    dockerargs_file = get_lineup_dockerargs_file(lineup)
    docker_args = _parse_dockerargs(dockerargs_file)
    tag_postfix = docker_args.get("TAG_POSTFIX", "")

    slug = branch_to_slug(branch)
    tag = f"{slug}-{git_tag}{tag_postfix}"
    return f"{registry}/{author}/{name}:{tag}"


def is_image_available(image_ref: str) -> bool:
    """Check if a Docker image exists locally."""
    try:
        result = subprocess.run(
            ["docker", "image", "inspect", image_ref],
            capture_output=True,
            text=True,
        )
        return result.returncode == 0
    except FileNotFoundError:
        return False


def get_flavor(branch: str) -> str:
    """Extract flavor from branch name: 'featured/base' -> 'featured'."""
    return branch.split("/")[0]


def get_image_dependencies() -> dict[str, str | None]:
    """Return {branch: depends_on} mapping from images.json."""
    config = _load_config()
    return {k: v.get("depends_on") for k, v in config["images"].items()}
