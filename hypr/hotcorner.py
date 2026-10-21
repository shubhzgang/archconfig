#!/usr/bin/env python3
"""Hot corner: push the cursor into the top-left corner to toggle the rofi launcher.

Polls Hyprland's command socket directly (no hyprctl process per check), so the
cost stays well under 1% of a core. Fires once per visit to the corner.
"""
import glob
import os
import socket
import subprocess
import sys
import time

ZONE = 5          # px, top-left square that triggers the launcher
INTERVAL = 0.05   # s between cursor checks
LAUNCH = ["rofi", "-show", "drun"]

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


def rofi_running():
    return subprocess.run(["pgrep", "-x", "rofi"], capture_output=True).returncode == 0


def main():
    path = socket_path()
    armed = True
    while True:
        try:
            x, y = cursor_pos(path)
        except (OSError, ValueError):
            sys.exit("hotcorner: lost Hyprland socket")  # systemd restarts us
        in_corner = x < ZONE and y < ZONE
        if in_corner and armed:
            if rofi_running():
                subprocess.run(["pkill", "-x", "rofi"])
            else:
                subprocess.Popen(LAUNCH, start_new_session=True)
        armed = not in_corner
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
