"""Container lifecycle management with cleanup resilience and log collection."""

from __future__ import annotations

import atexit
import logging
import signal
import socket
import subprocess
import time
from pathlib import Path

import requests

from .constants import BOOTSTRAP_WAIT, CONTAINER_LABEL, HEALTH_POLL_INTERVAL, HEALTH_TIMEOUT

logger = logging.getLogger(__name__)

# Global registry of running containers for signal/atexit cleanup
_running_containers: dict[str, "ContainerManager"] = {}


def _cleanup_all() -> None:
    """Force-remove all tracked containers. Called by atexit and signal handlers."""
    for cm in list(_running_containers.values()):
        try:
            cm.stop()
        except Exception:
            pass


def _signal_handler(signum, frame):
    _cleanup_all()
    raise SystemExit(128 + signum)


# Register cleanup handlers once at import time
atexit.register(_cleanup_all)
for _sig in (signal.SIGINT, signal.SIGTERM):
    try:
        signal.signal(_sig, _signal_handler)
    except (OSError, ValueError):
        pass  # Can't set signal handler in non-main thread


def cleanup_stale_containers() -> None:
    """Remove any leftover containers from interrupted prior runs."""
    try:
        result = subprocess.run(
            ["docker", "ps", "-aq", "--filter", f"label={CONTAINER_LABEL}=1"],
            capture_output=True,
            text=True,
        )
        container_ids = result.stdout.strip().splitlines()
        if container_ids:
            logger.info("Cleaning up %d stale test containers", len(container_ids))
            subprocess.run(
                ["docker", "rm", "-f", *container_ids],
                capture_output=True,
            )
    except Exception as exc:
        logger.warning("Failed to clean up stale containers: %s", exc)


def allocate_port() -> int:
    """Allocate a free ephemeral port via OS binding."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class ContainerManager:
    """Manages a single Docker container's lifecycle."""

    def __init__(
        self,
        image_ref: str,
        branch: str,
        output_dir: Path,
        extra_env: dict[str, str] | None = None,
        privileged: bool = False,
        extra_ports: dict[int, int] | None = None,
    ):
        self.image_ref = image_ref
        self.branch = branch
        self.slug = branch.replace("/", "-")
        self.output_dir = output_dir
        self.extra_env = extra_env or {}
        self.privileged = privileged
        self.extra_ports = extra_ports or {}

        self.container_id: str | None = None
        self.host_port: int | None = None
        self._started = False

    @property
    def base_url(self) -> str:
        return f"http://127.0.0.1:{self.host_port}"

    def start(self, retries: int = 3) -> None:
        """Start the container with retry on port conflicts."""
        for attempt in range(retries):
            self.host_port = allocate_port()
            port_mappings = ["-p", f"127.0.0.1:{self.host_port}:80"]

            # Allocate extra ports (e.g., SSH)
            for container_port, host_port_override in self.extra_ports.items():
                port_mappings.extend(
                    ["-p", f"127.0.0.1:{host_port_override}:{container_port}"]
                )

            env_flags = ["-e", "IDEKUBE_INIT_HOME=true"]
            for key, value in self.extra_env.items():
                env_flags.extend(["-e", f"{key}={value}"])

            cmd = [
                "docker",
                "run",
                "-d",
                "--label",
                f"{CONTAINER_LABEL}=1",
                *port_mappings,
                *env_flags,
            ]

            if self.privileged:
                cmd.append("--privileged")

            cmd.append(self.image_ref)

            try:
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    check=True,
                )
                self.container_id = result.stdout.strip()[:12]
                self._started = True
                _running_containers[self.container_id] = self
                logger.info(
                    "Started container %s (%s) on port %d",
                    self.container_id,
                    self.branch,
                    self.host_port,
                )
                return
            except subprocess.CalledProcessError as exc:
                if "port is already allocated" in exc.stderr and attempt < retries - 1:
                    logger.warning(
                        "Port %d in use, retrying (%d/%d)",
                        self.host_port,
                        attempt + 1,
                        retries,
                    )
                    continue
                raise RuntimeError(
                    f"Failed to start container {self.image_ref}: {exc.stderr}"
                ) from exc

        raise RuntimeError(f"Failed to allocate port after {retries} retries")

    def wait_healthy(self, timeout: int = HEALTH_TIMEOUT, bootstrap_wait: int = BOOTSTRAP_WAIT) -> dict:
        """Wait for bootstrap, then poll /health until it returns 200. Returns parsed JSON."""
        # Give the container time to bootstrap (supervisord, services starting)
        if bootstrap_wait > 0:
            logger.info(
                "Waiting %ds for %s to bootstrap...", bootstrap_wait, self.branch
            )
            time.sleep(bootstrap_wait)

        url = f"{self.base_url}/health"
        deadline = time.monotonic() + timeout
        last_error = None

        while time.monotonic() < deadline:
            try:
                resp = requests.get(url, timeout=5)
                if resp.status_code == 200:
                    return resp.json()
            except requests.ConnectionError:
                pass
            except requests.Timeout:
                pass
            except Exception as exc:
                last_error = exc

            time.sleep(HEALTH_POLL_INTERVAL)

        self.collect_logs()
        raise TimeoutError(
            f"Container {self.branch} ({self.container_id}) did not become healthy "
            f"within {timeout}s. Last error: {last_error}"
        )

    def exec_run(self, cmd: str | list[str], user: str | None = None) -> subprocess.CompletedProcess:
        """Run a command inside the container via docker exec."""
        if isinstance(cmd, str):
            exec_cmd = ["docker", "exec", self.container_id, "bash", "-c", cmd]
        else:
            exec_cmd = ["docker", "exec", self.container_id, *cmd]

        if user:
            exec_cmd.insert(2, "--user")
            exec_cmd.insert(3, user)

        return subprocess.run(exec_cmd, capture_output=True, text=True, timeout=30)

    def collect_logs(self) -> Path | None:
        """Collect docker logs and save to output directory."""
        if not self.container_id:
            return None
        try:
            logs_dir = self.output_dir / "logs"
            logs_dir.mkdir(parents=True, exist_ok=True)
            log_path = logs_dir / f"{self.slug}.log"

            result = subprocess.run(
                ["docker", "logs", self.container_id],
                capture_output=True,
                text=True,
                timeout=10,
            )
            log_path.write_text(
                f"=== STDOUT ===\n{result.stdout}\n\n=== STDERR ===\n{result.stderr}\n"
            )
            logger.info("Collected logs for %s -> %s", self.branch, log_path)
            return log_path
        except Exception as exc:
            logger.warning("Failed to collect logs for %s: %s", self.branch, exc)
            return None

    def stop(self) -> None:
        """Stop and remove the container, collecting logs first."""
        if not self.container_id:
            return

        # Best-effort log collection before stopping
        self.collect_logs()

        try:
            subprocess.run(
                ["docker", "rm", "-f", self.container_id],
                capture_output=True,
                timeout=15,
            )
            logger.info("Stopped container %s (%s)", self.container_id, self.branch)
        except subprocess.TimeoutExpired:
            logger.warning("Timeout stopping container %s", self.container_id)
        except Exception as exc:
            logger.warning("Failed to stop container %s: %s", self.container_id, exc)

        _running_containers.pop(self.container_id, None)
        self.container_id = None
        self._started = False
