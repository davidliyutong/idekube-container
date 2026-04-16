"""Environment variable configuration tests — parametrized across all branches.

Tests IDEKUBE_INIT_HOME, IDEKUBE_PREFERED_SHELL, IDEKUBE_USER_UID,
IDEKUBE_AUTHORIZED_KEYS, and non-root user mode.

Uses a single "env" container per branch (pool key: "{branch}:env") with all
env vars combined to minimize container starts.
"""

from __future__ import annotations

import pytest

from conftest import (
    TEST_SSH_AUTHORIZED_KEYS_B64,
    attach_log,
    get_branch_params,
    get_or_start_container,
    resolve_and_check,
)


def pytest_generate_tests(metafunc):
    if "branch" in metafunc.fixturenames:
        metafunc.parametrize("branch", get_branch_params(metafunc.config), indirect=False)


def _get_env_container(branch, lineup, container_pool, output_dir):
    """Get or start a container with all env vars set for testing."""
    image_ref = resolve_and_check(branch, lineup)
    return get_or_start_container(
        container_pool,
        branch,
        image_ref,
        output_dir,
        extra_env={
            "IDEKUBE_INIT_HOME": "true",
            "IDEKUBE_PREFERED_SHELL": "/bin/zsh",
            "IDEKUBE_USER_UID": "1234",
            "IDEKUBE_AUTHORIZED_KEYS": TEST_SSH_AUTHORIZED_KEYS_B64,
        },
        pool_key=f"{branch}:env",
    )


class TestEnvConfig:
    """Verify environment variable configurations on every branch."""

    def test_init_home(self, branch, container_pool, output_dir, lineup, request):
        """IDEKUBE_INIT_HOME should populate home from /etc/skel."""
        cm = _get_env_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        result = cm.exec_run("ls -la /home/idekube/.bashrc", user="idekube")
        assert result.returncode == 0, f".bashrc not found in home: {result.stderr}"

    def test_preferred_shell(self, branch, container_pool, output_dir, lineup, request):
        """IDEKUBE_PREFERED_SHELL=/bin/zsh should set the user's shell."""
        cm = _get_env_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        result = cm.exec_run("getent passwd idekube | cut -d: -f7")
        shell = result.stdout.strip()
        assert shell == "/bin/zsh", f"Expected /bin/zsh, got {shell}"

    def test_user_uid(self, branch, container_pool, output_dir, lineup, request):
        """IDEKUBE_USER_UID=1234 should override the user's UID."""
        cm = _get_env_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        result = cm.exec_run("id -u idekube")
        uid = result.stdout.strip()
        assert uid == "1234", f"Expected UID 1234, got {uid}"

    def test_authorized_keys(self, branch, container_pool, output_dir, lineup, request):
        """IDEKUBE_AUTHORIZED_KEYS should inject SSH public keys."""
        cm = _get_env_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        result = cm.exec_run("cat /home/idekube/.ssh/authorized_keys", user="idekube")
        assert result.returncode == 0, f"authorized_keys not found: {result.stderr}"
        assert "TestKeyForIDEKubeContainerTests" in result.stdout

    def test_non_root_user(self, branch, container_pool, output_dir, lineup, request):
        """The idekube user should not have UID 0 (non-root)."""
        # Use the default container (not the env one) to check default behavior
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)
        result = cm.exec_run("id -u idekube")
        uid = result.stdout.strip()
        assert uid != "0", "idekube user should not be root (UID 0)"
