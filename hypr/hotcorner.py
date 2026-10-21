#!/usr/bin/env python3
"""Hot zones: push the cursor into the top-left corner to toggle the rofi launcher,
or against the middle of the left edge to toggle the btop scratchpad.

Polls Hyprland's command socket directly (no hyprctl process per check), so the
cost stays well under 1% of a core. Fires once per visit to the corner.
"""
import glob
import json
import os
import socket
import subprocess
import sys
import time

ZONE = 5          # px, top-left square that triggers the launcher
INTERVAL = 0.05   # s between cursor checks
LAUNCH = ["rofi", "-show", "drun"]
EDGE = 2          # px, left-edge strip that triggers the stats scratchpad
EDGE_MARGIN = 0.1 # fraction of screen height ignored at top and bottom of the edge
STATS = ["pypr", "toggle", "taskbar"]

runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")


def socket_path():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig:
        return f"{runtime}/hypr/{sig}/.socket.sock"
    paths = glob.glob(f"{runtime}/hypr/*/.socket.sock")
    if not paths:
        sys.exit("hotcorner: no Hyprland socket found")
    return max(paths, key=os.path.getmtime)


def cursor_pos(path):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(path)
        s.sendall(b"cursorpos")
        data = b""
        while chunk := s.recv(64):
            data += chunk
    x, y = data.decode().split(",")
    return int(x), int(y)


def screen_height(path):
    """Height of the monitor at the layout origin (where both zones live)."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(path)
        s.sendall(b"j/monitors")
        data = b""
        while chunk := s.recv(4096):
            data += chunk
    for m in json.loads(data):
        if m["x"] == 0 and m["y"] == 0:
            return int(m["height"] / m["scale"])
    return 0


def rofi_running():
    return subprocess.run(["pgrep", "-x", "rofi"], capture_output=True).returncode == 0


def main():
    path = socket_path()
    height = screen_height(path)
    armed = {"corner": True, "edge": True}
    last_refresh = time.monotonic()
    while True:
        try:
            x, y = cursor_pos(path)
            if time.monotonic() - last_refresh > 10:
                height, last_refresh = screen_height(path), time.monotonic()
        except (OSError, ValueError):
            sys.exit("hotcorner: lost Hyprland socket")  # systemd restarts us
        zones = {
            "corner": x < ZONE and y < ZONE,
            "edge": x < EDGE and height * EDGE_MARGIN <= y <= height * (1 - EDGE_MARGIN),
        }
        if zones["corner"] and armed["corner"]:
            if rofi_running():
                subprocess.run(["pkill", "-x", "rofi"])
            else:
                subprocess.Popen(LAUNCH, start_new_session=True)
        if zones["edge"] and armed["edge"]:
            subprocess.Popen(STATS, start_new_session=True)
        armed = {k: not v for k, v in zones.items()}
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
