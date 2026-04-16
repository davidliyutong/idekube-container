"""Access token authentication tests — parametrized across all branches.

Each branch gets a separate auth-enabled container (pool key: "{branch}:auth").
"""

from __future__ import annotations

import pytest
import requests as http_requests

from conftest import (
    ACCESS_TOKEN,
    attach_log,
    get_branch_params,
    get_or_start_container,
    resolve_and_check,
    save_screenshot,
)
from helpers.constants import PRIVILEGED_BRANCHES


def pytest_generate_tests(metafunc):
    if "branch" in metafunc.fixturenames:
        metafunc.parametrize("branch", get_branch_params(metafunc.config), indirect=False)


def _get_auth_container(branch, lineup, container_pool, output_dir):
    """Get or start an auth-enabled container for this branch."""
    image_ref = resolve_and_check(branch, lineup)
    return get_or_start_container(
        container_pool,
        branch,
        image_ref,
        output_dir,
        extra_env={"IDEKUBE_ACCESS_TOKEN": ACCESS_TOKEN},
        pool_key=f"{branch}:auth",
    )


class TestAccessTokenAuth:
    """Verify nginx-level access token authentication on every branch."""

    def test_unauthenticated_blocked(self, branch, container_pool, output_dir, lineup, request):
        cm = _get_auth_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        resp = http_requests.get(f"{cm.base_url}/", timeout=10, allow_redirects=False)
        assert resp.status_code == 401, f"Expected 401, got {resp.status_code}"

    def test_query_param_auth(self, branch, container_pool, output_dir, lineup, page, request):
        cm = _get_auth_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        url = f"{cm.base_url}/?idekube-container-access-token={ACCESS_TOKEN}"
        resp = page.goto(url, wait_until="networkidle", timeout=30000)
        assert resp is not None
        assert resp.status != 401, "Query param auth should not return 401"
        assert resp.status < 500, f"Query param auth returned {resp.status}"
        save_screenshot(request.node, page, f"{branch.replace('/', '-')}_auth_query")

    def test_cookie_set_after_query_param(self, branch, container_pool, output_dir, lineup, page, request):
        cm = _get_auth_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        url = f"{cm.base_url}/?idekube-container-access-token={ACCESS_TOKEN}"
        page.goto(url, wait_until="networkidle", timeout=30000)
        cookie_names = [c["name"] for c in page.context.cookies()]
        assert "idekube_container_access_token" in cookie_names, (
            f"Expected cookie 'idekube_container_access_token' in {cookie_names}"
        )

    def test_cookie_auth(self, branch, container_pool, output_dir, lineup, page, request):
        cm = _get_auth_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        page.context.add_cookies([{
            "name": "idekube_container_access_token",
            "value": ACCESS_TOKEN,
            "url": cm.base_url,
        }])
        resp = page.goto(cm.base_url, wait_until="networkidle", timeout=30000)
        assert resp is not None
        assert resp.status != 401, "Cookie auth should not return 401"
        save_screenshot(request.node, page, f"{branch.replace('/', '-')}_auth_cookie")

    def test_header_auth(self, branch, container_pool, output_dir, lineup, request):
        cm = _get_auth_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        resp = http_requests.get(
            f"{cm.base_url}/",
            headers={"X-IDEKUBE-Container-Access-Token": ACCESS_TOKEN},
            timeout=10,
            allow_redirects=False,
        )
        assert resp.status_code != 401, "Header auth returned 401"

    def test_ssh_excluded_from_auth(self, branch, container_pool, output_dir, lineup, request):
        cm = _get_auth_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        resp = http_requests.get(f"{cm.base_url}/ssh", timeout=10, allow_redirects=False)
        assert resp.status_code != 401, f"/ssh should not require auth, got {resp.status_code}"

    def test_health_excluded_from_auth(self, branch, container_pool, output_dir, lineup, request):
        cm = _get_auth_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        resp = http_requests.get(f"{cm.base_url}/health", timeout=10)
        assert resp.status_code == 200, f"/health should not require auth, got {resp.status_code}"

    def test_wrong_token_rejected(self, branch, container_pool, output_dir, lineup, request):
        cm = _get_auth_container(branch, lineup, container_pool, output_dir)
        attach_log(request.node, cm)
        resp = http_requests.get(
            f"{cm.base_url}/",
            headers={"X-IDEKUBE-Container-Access-Token": "wrong-token"},
            timeout=10,
            allow_redirects=False,
        )
        assert resp.status_code == 401, f"Wrong token should be rejected, got {resp.status_code}"
