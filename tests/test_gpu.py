"""GPU-dependent tests — parametrized across all branches.

Skipped if NVIDIA runtime is not available.
GPU tests (glxgears, chromium hw accel) are only meaningful for desktop branches (featured/*).
nvidia-smi is tested on all branches when GPU is available.
"""

from __future__ import annotations

import subprocess

import pytest

from conftest import attach_log, get_branch_params, resolve_and_check
from helpers.constants import CONTAINER_LABEL, DESKTOP_BRANCHES, PRIVILEGED_BRANCHES
from helpers.containers import ContainerManager, allocate_port


def pytest_generate_tests(metafunc):
    if "branch" in metafunc.fixturenames:
        metafunc.parametrize("branch", get_branch_params(metafunc.config), indirect=False)


def _get_gpu_container(branch, lineup, container_pool, output_dir, nvidia_runtime_available):
    """Get or start a GPU-enabled container."""
    if not nvidia_runtime_available:
        pytest.skip("NVIDIA runtime not available")

    from conftest import resolve_and_check

    image_ref = resolve_and_check(branch, lineup)

    pool_key = f"{branch}:gpu"
    if pool_key in container_pool:
        return container_pool[pool_key]

    host_port = allocate_port()
    cmd = [
        "docker", "run", "-d",
        "--label", f"{CONTAINER_LABEL}=1",
        "--gpus", "all",
        "-p", f"127.0.0.1:{host_port}:80",
        "-e", "IDEKUBE_INIT_HOME=true",
        "-e", "NVIDIA_DRIVER_CAPABILITIES=all",
    ]
    if branch in PRIVILEGED_BRANCHES:
        cmd.append("--privileged")
    cmd.append(image_ref)

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as exc:
        pytest.skip(f"Failed to start GPU container: {exc.stderr}")

    cm = ContainerManager(
        image_ref=image_ref,
        branch=branch,
        output_dir=output_dir,
        privileged=branch in PRIVILEGED_BRANCHES,
    )
    cm.container_id = result.stdout.strip()[:12]
    cm.host_port = host_port
    cm._started = True
    cm.wait_healthy()
    container_pool[pool_key] = cm
    return cm


@pytest.mark.gpu
class TestGPU:
    """GPU-specific tests. All skip if no NVIDIA runtime."""

    def test_nvidia_smi(self, branch, container_pool, output_dir, lineup, nvidia_runtime_available, request):
        cm = _get_gpu_container(branch, lineup, container_pool, output_dir, nvidia_runtime_available)
        attach_log(request.node, cm)
        result = cm.exec_run("nvidia-smi")
        assert result.returncode == 0, f"nvidia-smi failed: {result.stderr}"
        assert "NVIDIA" in result.stdout or "GPU" in result.stdout

    def test_glxgears(self, branch, container_pool, output_dir, lineup, nvidia_runtime_available, request):
        """VirtualGL glxgears — only for desktop branches."""
        if branch not in DESKTOP_BRANCHES:
            pytest.skip(f"{branch} is not a desktop branch (no VirtualGL)")
        cm = _get_gpu_container(branch, lineup, container_pool, output_dir, nvidia_runtime_available)
        attach_log(request.node, cm)
        result = cm.exec_run("timeout 3 vglrun glxgears -info 2>&1 || true")
        output = result.stdout + result.stderr
        assert "error" not in output.lower() or "GL_RENDERER" in output, (
            f"glxgears may have failed: {output[:500]}"
        )

    def test_chromium_gpu(self, branch, container_pool, output_dir, lineup, nvidia_runtime_available, request):
        """Chromium with GPU — only for desktop branches."""
        if branch not in DESKTOP_BRANCHES:
            pytest.skip(f"{branch} is not a desktop branch (no Chromium desktop)")
        cm = _get_gpu_container(branch, lineup, container_pool, output_dir, nvidia_runtime_available)
        attach_log(request.node, cm)
        result = cm.exec_run(
            "chromium --headless --no-sandbox --disable-gpu-sandbox "
            "--dump-dom --virtual-time-budget=3000 chrome://gpu 2>/dev/null | head -50"
        )
        assert len(result.stdout) > 0, "Chromium produced no output"
