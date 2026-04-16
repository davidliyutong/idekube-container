"""SSH connectivity tests — parametrized across all branches."""

from __future__ import annotations

import socket

import pytest
import requests

from conftest import attach_log, get_branch_params, get_or_start_container, resolve_and_check


def pytest_generate_tests(metafunc):
    if "branch" in metafunc.fixturenames:
        metafunc.parametrize("branch", get_branch_params(metafunc.config), indirect=False)


class TestSSH:
    """Verify SSH connectivity through the websocat WebSocket tunnel."""

    def test_ssh_port_open(self, branch, container_pool, output_dir, lineup, request):
        """The websocat SSH port (2222 mapped to host) should accept TCP connections."""
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        ssh_host_port = None
        for container_port, host_port in cm.extra_ports.items():
            if container_port == 2222:
                ssh_host_port = host_port
                break

        if ssh_host_port is None:
            pytest.skip("SSH port not mapped for this container")

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        try:
            sock.connect(("127.0.0.1", ssh_host_port))
            sock.close()
        except (ConnectionRefusedError, socket.timeout, OSError) as exc:
            pytest.fail(f"SSH websocat port {ssh_host_port} not reachable: {exc}")

    def test_ssh_endpoint_http(self, branch, container_pool, output_dir, lineup, request):
        """/ssh endpoint via nginx should respond (not 502 or 404)."""
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        resp = requests.get(f"{cm.base_url}/ssh", timeout=10)
        assert resp.status_code != 502, "/ssh returned 502 — websocat may not be running"
        assert resp.status_code != 404, "/ssh returned 404 — endpoint not configured"
