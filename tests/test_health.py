"""Tests for the /health endpoint — parametrized across all branches."""

from __future__ import annotations

import pytest
import requests

from conftest import attach_log, get_branch_params, get_or_start_container, resolve_and_check
from helpers.constants import get_expected_health


def pytest_generate_tests(metafunc):
    if "branch" in metafunc.fixturenames:
        metafunc.parametrize("branch", get_branch_params(metafunc.config), indirect=False)


class TestHealthEndpoint:
    """Validate /health returns correct JSON for every image."""

    def test_health_returns_200(self, branch, container_pool, output_dir, lineup, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        resp = requests.get(f"{cm.base_url}/health", timeout=10)
        assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
        data = resp.json()
        assert "status" in data
        assert "services" in data
        assert data["status"] in ("healthy", "degraded")

    def test_health_has_correct_services(self, branch, container_pool, output_dir, lineup, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        resp = requests.get(f"{cm.base_url}/health", timeout=10)
        data = resp.json()
        expected = get_expected_health(branch)
        assert set(expected["services"]) == set(data["services"]), (
            f"Expected services {set(expected['services'])}, got {set(data['services'])}"
        )

    def test_health_has_entry(self, branch, container_pool, output_dir, lineup, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        resp = requests.get(f"{cm.base_url}/health", timeout=10)
        data = resp.json()
        assert "entry" in data and data["entry"]

    def test_health_no_auth_required(self, branch, container_pool, output_dir, lineup, request):
        """Even containers with auth should expose /health without auth."""
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        resp = requests.get(f"{cm.base_url}/health", timeout=10)
        assert resp.status_code == 200
