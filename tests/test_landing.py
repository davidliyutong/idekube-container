"""Tests for the landing page (/) — parametrized across all branches."""

from __future__ import annotations

import pytest

from conftest import (
    attach_log,
    get_branch_params,
    get_or_start_container,
    resolve_and_check,
    save_screenshot,
)


def pytest_generate_tests(metafunc):
    if "branch" in metafunc.fixturenames:
        metafunc.parametrize("branch", get_branch_params(metafunc.config), indirect=False)


class TestLandingPage:
    """Verify the landing page loads and shows available services."""

    def test_landing_page_loads(self, branch, container_pool, output_dir, lineup, page, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        slug = branch.replace("/", "-")
        page.goto(cm.base_url, wait_until="networkidle", timeout=30000)
        assert page.locator("body").is_visible()
        save_screenshot(request.node, page, f"{slug}_landing")

    def test_landing_page_no_502(self, branch, container_pool, output_dir, lineup, page, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        resp = page.goto(cm.base_url, wait_until="networkidle", timeout=30000)
        assert resp is not None
        assert resp.status != 502, "Landing page returned 502 Bad Gateway"

    def test_landing_page_shows_services(self, branch, container_pool, output_dir, lineup, page, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        page.goto(cm.base_url, wait_until="networkidle", timeout=30000)
        content = page.content()
        assert len(content) > 200, "Landing page content seems too short"
        save_screenshot(request.node, page, f"{branch.replace('/', '-')}_landing_services")

    def test_landing_page_theme_toggle(self, branch, container_pool, output_dir, lineup, page, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        page.goto(cm.base_url, wait_until="networkidle", timeout=30000)
        toggle = page.locator("[data-testid='theme-toggle'], .theme-toggle, button:has-text('🌙'), button:has-text('☀')")
        if toggle.count() > 0:
            toggle.first.click()
            page.wait_for_timeout(500)
            save_screenshot(request.node, page, f"{branch.replace('/', '-')}_landing_theme")
        else:
            pytest.skip("Theme toggle not found on this landing page version")

    def test_landing_page_i18n(self, branch, container_pool, output_dir, lineup, page, request):
        image_ref = resolve_and_check(branch, lineup)
        cm = get_or_start_container(container_pool, branch, image_ref, output_dir)
        attach_log(request.node, cm)

        page.goto(cm.base_url, wait_until="networkidle", timeout=30000)
        toggle = page.locator("[data-testid='lang-toggle'], .lang-toggle, button:has-text('中'), button:has-text('EN')")
        if toggle.count() > 0:
            toggle.first.click()
            page.wait_for_timeout(500)
            save_screenshot(request.node, page, f"{branch.replace('/', '-')}_landing_i18n")
        else:
            pytest.skip("Language toggle not found on this landing page version")
