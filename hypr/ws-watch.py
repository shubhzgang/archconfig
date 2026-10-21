#!/usr/bin/env python3
"""Tell waybar to refresh its workspace dots when workspaces or windows change.

Waybar's hyprland/workspaces module can't switch workspaces under the Lua config
(it sends legacy `dispatch workspace N`), so the dots are custom modules
(waybar/scripts/ws.sh) refreshed via SIGRTMIN+9 from here.
"""
import glob
import os
import socket
import subprocess
import sys

SIGNAL = "RTMIN+9"
EVENTS = ("workspace", "workspacev2", "createworkspace", "destroyworkspace",
          "openwindow", "closewindow", "movewindow", "movewindowv2",
          "focusedmon", "moveworkspace")

runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
paths = [f"{runtime}/hypr/{sig}/.socket2.sock"] if sig else glob.glob(f"{runtime}/hypr/*/.socket2.sock")
if not paths:
    sys.exit("ws-watch: no Hyprland event socket found")

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
    s.connect(max(paths, key=os.path.getmtime))
    for line in s.makefile("r", errors="replace"):
        if line.split(">>", 1)[0] in EVENTS:
            subprocess.run(["pkill", f"-{SIGNAL}", "-x", "waybar"])
sys.exit("ws-watch: Hyprland socket closed")  # systemd restarts us
