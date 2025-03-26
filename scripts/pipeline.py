import os
import json
import sys

REGISTRY = os.getenv("REGISTRY", "docker.io")
AUTHOR = os.getenv("AUTHOR", "davidliyutong")
NAME = os.getenv("NAME", "idekube-container")
GIT_TAG = os.getenv("GIT_TAG", "latest")
STRATEGY = os.getenv("STRATEGY", "buildx")
ACTION = os.getenv("ACTION", "build")

BASE_IMAGES = ["ubuntu:20.04", "ubuntu:22.04", "ubuntu:24.04"]
BRANCHES = {
    "featured/base": {"featured/speit": {}, "featured/dind": {}, "featured/ros2": {}},
    "coder/base": {},
    "coder/lite": {},
    "jupyter/base": {"jupyter/speit": {}},
}
ARCHS = ["amd64", "arm64"]
STRATEGIES = ["native", "buildx"]
ACTIONS = ["build", "publish"]

# Assertions
assert STRATEGY in STRATEGIES, f"Invalid STRATEGY: {STRATEGY}"
assert ACTION in ACTIONS, f"Invalid ACTION: {ACTION}"

def render_images(base_image, branch: str, arch: str) -> list[str]:
    branch = branch.replace("/", "-")
    base_image_version = base_image.split(":")[1]
    if arch != "buildx":
        return f"{REGISTRY}/{AUTHOR}/{NAME}:{branch}-{base_image_version}-{GIT_TAG}-{arch}"
    else:
        return f"{REGISTRY}/{AUTHOR}/{NAME}:{branch}-{base_image_version}-{GIT_TAG}"

def render_build_all_targets(buildx: bool=False):
    archs = ["buildx"] if buildx else ARCHS
    images = {base_images:{arch: {} for arch in archs} for base_images in BASE_IMAGES}

    for base_image in BASE_IMAGES:
        for arch in archs:
            for branch, sub_branches in BRANCHES.items():
                images[base_image][arch][branch] = [
                    [render_images(base_image, branch, arch)],
                    [
                        render_images(base_image, sub_branch, arch) for sub_branch in sub_branches.keys()
                    ]
                ]
    return images


def main():
    import pprint
    pprint.pprint(render_build_all_targets(True))

main()