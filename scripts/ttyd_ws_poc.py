#!/usr/bin/env python3
"""PoC: control a ttyd terminal over WebSocket.

Usage:
    # Interactive mode (default)
    python3 ttyd_ws_poc.py

    # Run a single command and print output
    python3 ttyd_ws_poc.py -c "ls -la /tmp"

    # Custom endpoint
    python3 ttyd_ws_poc.py --url http://localhost:3000/terminal

    # With access token
    python3 ttyd_ws_poc.py --token mytoken -c "whoami"

Requires: pip install websocket-client
"""

import argparse
import json
import re
import sys
import threading
import time

import websocket

# ttyd wire protocol opcodes
CLIENT_INPUT = "0"          # client -> server: raw keystrokes
CLIENT_RESIZE = "1"         # client -> server: JSON {"columns": N, "rows": N}
SERVER_OUTPUT = "0"          # server -> client: terminal output
SERVER_SET_TITLE = "1"       # server -> client: window title
SERVER_SET_PREFS = "2"       # server -> client: xterm.js preferences
CLIENT_JSON_DATA = "{"       # client -> server: initial auth/resize JSON

# Regex to strip ANSI escape sequences
_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]|\x1b\][^\x07]*\x07|\x1b\[\?[0-9;]*[hl]")


def build_ws_url(base_url: str) -> str:
    """Convert an HTTP(S) base URL to the ttyd WebSocket endpoint."""
    url = base_url.rstrip("/")
    ws_url = url.replace("https://", "wss://").replace("http://", "ws://")
    return ws_url + "/ws"


def fetch_token(base_url: str, access_token: str | None = None) -> str:
    """Fetch the ttyd auth token from the /token HTTP endpoint."""
    import urllib.request

    token_url = base_url.rstrip("/") + "/token"
    req = urllib.request.Request(token_url)
    if access_token:
        req.add_header("X-IDEKUBE-Container-Access-Token", access_token)
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            return data.get("token", "")
    except Exception:
        return ""


class TtydClient:
    """Minimal ttyd WebSocket client."""

    def __init__(self, base_url: str, access_token: str | None = None,
                 cols: int = 120, rows: int = 40):
        self.base_url = base_url
        self.access_token = access_token
        self.cols = cols
        self.rows = rows
        self.ws: websocket.WebSocket | None = None
        self._output_buf: list[str] = []
        self._lock = threading.Lock()
        self._receiver: threading.Thread | None = None
        self._running = False

    def connect(self):
        """Open WebSocket and send the initial handshake."""
        ws_url = build_ws_url(self.base_url)
        headers = {}
        if self.access_token:
            cookie = f"idekube_container_access_token={self.access_token}"
            headers["Cookie"] = cookie

        self.ws = websocket.create_connection(
            ws_url, header=headers, timeout=10,
            subprotocols=["tty"],
        )

        # Send initial JSON_DATA frame (auth + terminal size)
        auth_token = fetch_token(self.base_url, self.access_token)
        init_msg = json.dumps({
            "AuthToken": auth_token,
            "columns": self.cols,
            "rows": self.rows,
        })
        self.ws.send_binary(init_msg.encode())

        # Start background receiver
        self._running = True
        self._receiver = threading.Thread(target=self._recv_loop, daemon=True)
        self._receiver.start()

    def _recv_loop(self):
        """Read frames from ttyd and buffer output."""
        while self._running and self.ws:
            try:
                _, data = self.ws.recv_data(control_frame=True)
                if not data:
                    continue
                opcode = chr(data[0])
                payload = data[1:]
                if opcode == SERVER_OUTPUT:
                    text = payload.decode("utf-8", errors="replace")
                    with self._lock:
                        self._output_buf.append(text)
                # SET_TITLE and SET_PREFS are silently consumed
            except websocket.WebSocketConnectionClosedException:
                break
            except Exception:
                break

    def send_input(self, text: str):
        """Send keystrokes to the terminal."""
        if self.ws:
            frame = CLIENT_INPUT.encode() + text.encode()
            self.ws.send_binary(frame)

    def send_line(self, command: str):
        """Send a command followed by Enter."""
        self.send_input(command + "\n")

    def read_output(self, timeout: float = 2.0, settle: float = 0.5) -> str:
        """Wait for output to settle, then return accumulated text.

        Args:
            timeout: Max seconds to wait for any output.
            settle:  Seconds of silence before considering output complete.
        """
        deadline = time.time() + timeout
        last_len = 0
        last_change = time.time()

        while time.time() < deadline:
            with self._lock:
                cur_len = sum(len(s) for s in self._output_buf)
            if cur_len != last_len:
                last_len = cur_len
                last_change = time.time()
            elif time.time() - last_change >= settle:
                break
            time.sleep(0.05)

        with self._lock:
            output = "".join(self._output_buf)
            self._output_buf.clear()
        return output

    def run_command(self, command: str, timeout: float = 5.0) -> str:
        """Send a command and return its output."""
        # Drain any pending output
        self.read_output(timeout=0.5, settle=0.3)
        self.send_line(command)
        return self.read_output(timeout=timeout)

    def close(self):
        self._running = False
        if self.ws:
            self.ws.close()

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, *_):
        self.close()


def interactive_mode(client: TtydClient):
    """Forward stdin to ttyd, print output continuously."""
    import selectors
    import os

    # Print output in background
    def printer():
        while client._running:
            out = client.read_output(timeout=0.2, settle=0.1)
            if out:
                sys.stdout.write(out)
                sys.stdout.flush()

    t = threading.Thread(target=printer, daemon=True)
    t.start()

    print("--- ttyd interactive session (Ctrl-C to exit) ---")
    try:
        if os.isatty(sys.stdin.fileno()):
            import tty
            import termios
            old = termios.tcgetattr(sys.stdin)
            tty.setraw(sys.stdin)
            try:
                while True:
                    sel = selectors.DefaultSelector()
                    sel.register(sys.stdin, selectors.EVENT_READ)
                    events = sel.select(timeout=0.1)
                    for _ in events:
                        ch = sys.stdin.read(1)
                        if ch == "\x03":  # Ctrl-C
                            raise KeyboardInterrupt
                        client.send_input(ch)
                    sel.close()
            finally:
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old)
        else:
            for line in sys.stdin:
                client.send_line(line.rstrip("\n"))
                time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n--- session ended ---")


def main():
    parser = argparse.ArgumentParser(description="Control ttyd over WebSocket")
    parser.add_argument("--url", default="http://localhost:3000/terminal",
                        help="ttyd base URL (default: http://localhost:3000/terminal)")
    parser.add_argument("--token", default=None,
                        help="IDEKUBE_ACCESS_TOKEN value (if auth is enabled)")
    parser.add_argument("-c", "--command", default=None,
                        help="Run a single command and print output")
    parser.add_argument("--strip-ansi", action="store_true",
                        help="Strip ANSI escape codes from output")
    parser.add_argument("--cols", type=int, default=120)
    parser.add_argument("--rows", type=int, default=40)
    args = parser.parse_args()

    with TtydClient(args.url, access_token=args.token,
                    cols=args.cols, rows=args.rows) as client:
        if args.command:
            output = client.run_command(args.command)
            if args.strip_ansi:
                output = _ANSI_RE.sub("", output)
            print(output)
        else:
            interactive_mode(client)


if __name__ == "__main__":
    main()
