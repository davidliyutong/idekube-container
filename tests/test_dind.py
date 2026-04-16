"""Docker-in-Docker tests — parametrized across all branches.

Skipped for branches that are not DinD-capable (only featured/dind and featured/kathara).
Requires privileged mode.
"""

from __future__ import annotations

import time

import pytest

from conftest import attach_log, get_branch_params, get_or_start_container, resolve_and_check
from helpers.constants import DIND_BRANCHES


def pytest_generate_tests(metafunc):
    if "branch" in metafunc.fixturenames:
        metafunc.parametrize("branch", get_branch_params(metafunc.config), indirect=False)


@pytest.mark.dind
@pytest.mark.privileged
class TestDinD:
    """Docker-in-Docker functionality tests."""

    def _skip_if_not_dind(self, branch):
        if branch not in DIND_BRANCHES:
            pytest.skip(f"{branch} does not support Docker-in-Docker")

    def test_docker_info(self, branch, container_pool, output_dir, lineup, request):
        """docker info should succeed inside the DinD container."""
        self._skip_if_not_dind(branch)
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(
            container_pool, branch, image_ref, output_dir, privileged=True
        )
        attach_log(request.node, cm)

        # Retry: dockerd inside the container may still be starting
        for attempt in range(5):
            result = cm.exec_run("docker info", user="idekube")
            if result.returncode == 0:
                break
            time.sleep(5)

        assert result.returncode == 0, f"docker info failed: {result.stderr}"
        assert "Server" in result.stdout, "docker info output missing Server section"

    def test_docker_run_hello_world(self, branch, container_pool, output_dir, lineup, request):
        """docker run hello-world should succeed inside the DinD container."""
        self._skip_if_not_dind(branch)
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(
            container_pool, branch, image_ref, output_dir, privileged=True
        )
        attach_log(request.node, cm)

        result = cm.exec_run("docker run --rm hello-world", user="idekube")
        assert result.returncode == 0, f"docker run hello-world failed: {result.stderr}"
        assert "Hello from Docker" in result.stdout
