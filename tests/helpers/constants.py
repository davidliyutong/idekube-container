"""Per-branch service metadata and special branch classifications.

Service configs are derived from the health.json files baked into each image.
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# Default per-flavor service definitions (from artifacts/docker/<flavor>/rootfs/etc/idekube/health.json)
# ---------------------------------------------------------------------------

FLAVOR_HEALTH = {
    "featured": {
        "entry": "/vnc/",
        "main": "vnc",
        "services": {
            "vnc": {"port": 6081, "path": "/vnc/"},
            "coder": {"port": 3000, "path": "/coder/"},
            "ssh": {"port": 2222, "path": "/ssh"},
        },
    },
    "coder": {
        "entry": "/coder/",
        "main": "coder",
        "services": {
            "coder": {"port": 3000, "path": "/coder/"},
            "ssh": {"port": 2222, "path": "/ssh"},
        },
    },
    "jupyter": {
        "entry": "/jupyter/",
        "main": "jupyter",
        "services": {
            "jupyter": {"port": 8888, "path": "/jupyter/"},
            "ssh": {"port": 2222, "path": "/ssh"},
        },
    },
    "agent": {
        "entry": "/terminal",
        "main": "terminal",
        "services": {
            "terminal": {"port": 7681, "path": "/terminal"},
            "ssh": {"port": 2222, "path": "/ssh"},
        },
    },
}

# ---------------------------------------------------------------------------
# Branch-specific overrides (only for branches whose health.json differs from flavor default)
# ---------------------------------------------------------------------------

BRANCH_HEALTH_OVERRIDES: dict[str, dict] = {
    "agent/openclaw": {
        "entry": "/agent",
        "main": "agent",
        "services": {
            "agent": {"port": 18789, "path": "/agent"},
            "terminal": {"port": 7681, "path": "/terminal"},
            "ssh": {"port": 2222, "path": "/ssh"},
        },
    },
    # agent/hermes uses the default agent health config (no nginx override for hermes)
}

# ---------------------------------------------------------------------------
# Special branch flags
# ---------------------------------------------------------------------------

PRIVILEGED_BRANCHES = {"featured/dind", "featured/kathara"}

# Branches that have Docker-in-Docker capability
DIND_BRANCHES = {"featured/dind", "featured/kathara"}

# Branches with VNC/desktop (for GPU-specific tests like glxgears)
DESKTOP_BRANCHES = {
    "featured/base",
    "featured/speit",
    "featured/speit-ai",
    "featured/dind",
    "featured/kathara",
    "featured/ros2",
}

# Services that are browser-testable (have an nginx path on port 80)
BROWSER_TESTABLE_SERVICES = {"vnc", "coder", "jupyter", "terminal", "agent"}

# Bootstrap wait before health polling (seconds) — gives supervisord time to start
BOOTSTRAP_WAIT = 20

# Container startup timeout (seconds) — after bootstrap wait
HEALTH_TIMEOUT = 120

# Health poll interval (seconds)
HEALTH_POLL_INTERVAL = 2

# Container label for cleanup identification
CONTAINER_LABEL = "idekube-test"

# Maximum parallel test workers (containers running simultaneously)
MAX_PARALLEL = 2


def get_expected_health(branch: str) -> dict:
    """Return the expected health config for a branch."""
    if branch in BRANCH_HEALTH_OVERRIDES:
        return BRANCH_HEALTH_OVERRIDES[branch]
    flavor = branch.split("/")[0]
    if flavor not in FLAVOR_HEALTH:
        raise ValueError(f"Unknown flavor for branch {branch}")
    return FLAVOR_HEALTH[flavor]
