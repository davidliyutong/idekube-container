"""Per-service Playwright browser tests — parametrized across all (branch, service) pairs."""

from __future__ import annotations

import pytest

from conftest import (
    attach_log,
    get_or_start_container,
    get_service_params,
    resolve_and_check,
    save_screenshot,
)
from helpers.constants import get_expected_health


def pytest_generate_tests(metafunc):
    if "branch" in metafunc.fixturenames and "service_name" in metafunc.fixturenames:
        metafunc.parametrize(
            ("branch", "service_name"),
            get_service_params(metafunc.config),
            indirect=False,
        )


SERVICE_CHECKS = {
    "vnc": {
        "description": "noVNC desktop viewer",
        "selectors": ["canvas", "#noVNC_canvas", ".noVNC"],
        "title_contains": ["noVNC", "vnc"],
    },
    "coder": {
        "description": "Code Server IDE",
        "selectors": [".monaco-editor", "#workbench\\.parts\\.editor", "iframe"],
        "title_contains": ["code", "Code", "VS Code"],
    },
    "jupyter": {
        "description": "JupyterLab",
        "selectors": ["#main", ".jp-Launcher", "#jp-main-dock-panel", ".jupyter"],
        "title_contains": ["Jupyter", "jupyter"],
    },
    "terminal": {
        "description": "ttyd web terminal",
        "selectors": [".xterm", "#terminal", "canvas", ".terminal"],
        "title_contains": ["ttyd", "terminal", "Terminal"],
    },
    "agent": {
        "description": "openclaw agent gateway",
        "selectors": ["body"],
        "title_contains": [],
    },
}


class TestServices:
    """Verify each service endpoint loads in the browser."""

    def test_service_responds(self, branch, service_name, container_pool, output_dir, lineup, page, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        health = get_expected_health(branch)
        svc = health["services"][service_name]
        url = f"{cm.base_url}{svc['path']}"

        resp = page.goto(url, wait_until="domcontentloaded", timeout=30000)
        assert resp is not None
        assert resp.status < 500, f"Service {service_name} returned {resp.status}"

        slug = branch.replace("/", "-")
        save_screenshot(request.node, page, f"{slug}_{service_name}")

    def test_service_renders_ui(self, branch, service_name, container_pool, output_dir, lineup, page, request):
        if service_name not in SERVICE_CHECKS:
            pytest.skip(f"No UI checks defined for {service_name}")

        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        health = get_expected_health(branch)
        svc = health["services"][service_name]
        url = f"{cm.base_url}{svc['path']}"

        page.goto(url, wait_until="networkidle", timeout=60000)

        checks = SERVICE_CHECKS[service_name]
        title = page.title().lower()
        title_ok = not checks["title_contains"] or any(
            t.lower() in title for t in checks["title_contains"]
        )

        selector_found = False
        for selector in checks["selectors"]:
            try:
                if page.locator(selector).count() > 0:
                    selector_found = True
                    break
            except Exception:
                continue

        slug = branch.replace("/", "-")
        save_screenshot(request.node, page, f"{slug}_{service_name}_ui")

        assert title_ok or selector_found, (
            f"Service {service_name} ({checks['description']}): "
            f"title '{page.title()}' doesn't match {checks['title_contains']} "
            f"and none of selectors {checks['selectors']} found"
        )
