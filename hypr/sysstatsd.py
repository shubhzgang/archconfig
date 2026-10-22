#!/usr/bin/env python3
"""System stats sampler for the Quickshell stats corner and panel.

Samples CPU, RAM, network and NVIDIA GPUs once a second and publishes, under
$XDG_RUNTIME_DIR/sysstats/:
  state.json                       full state + history, read by the Quickshell stats panel
  cpu.json mem.json net.json gpu.json   one JSON line each (the numbers in the Quickshell corner)
Files are replaced atomically, so readers never see a partial write.

Sampling interval and history length come from sysstats.json next to this file
(there is no UI for it yet); edits are picked up immediately and reset the history.
"""
import json
import os
import subprocess
import threading
import time
from collections import deque

import psutil

CONFIG = os.path.expanduser("~/.config/hypr/sysstats.json")
DEFAULTS = {"interval": 1, "points": 120}
OUT = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "sysstats")


def load_config():
    cfg = dict(DEFAULTS)
    try:
        with open(CONFIG) as f:
            raw = json.load(f)
        cfg["interval"] = min(max(float(raw.get("interval", cfg["interval"])), 0.5), 60)
        cfg["points"] = min(max(int(raw.get("points", cfg["points"])), 10), 1000)
    except (OSError, ValueError, TypeError):
        pass
    return cfg


def config_mtime():
    try:
        return os.path.getmtime(CONFIG)
    except OSError:
        return 0


def fmt_bytes(n, rate=False, short=False):
    units = ("B", "K", "M", "G", "T") if short else ("B", "KiB", "MiB", "GiB", "TiB")
    for unit in units:
        if n < 1024 or unit == units[-1]:
            digits = 0 if unit == "B" else 1
            sep = "" if short else " "
            return f"{n:.{digits}f}{sep}{unit}" + ("/s" if rate else "")
        n /= 1024


class GpuReader(threading.Thread):
    """One persistent `nvidia-smi -l 1`; no process spawn per tick."""

    def __init__(self):
        super().__init__(daemon=True)
        self.gpus = {}  # index -> dict(name, util, mem_used, mem_total)

    def run(self):
        try:
            proc = subprocess.Popen(
                ["nvidia-smi", "--query-gpu=index,name,utilization.gpu,memory.used,memory.total",
                 "--format=csv,noheader,nounits", "-l", "1"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            return
        for line in proc.stdout:
            parts = [p.strip() for p in line.split(",")]
            if len(parts) != 5:
                continue
            try:
                self.gpus[int(parts[0])] = {
                    "name": parts[1].replace("NVIDIA GeForce ", ""),
                    "util": float(parts[2]),
                    "mem_used": float(parts[3]) * 2**20,
                    "mem_total": float(parts[4]) * 2**20,
                }
            except ValueError:
                pass


def net_counters():
    rx = tx = 0
    for nic, c in psutil.net_io_counters(pernic=True).items():
        if nic != "lo":
            rx += c.bytes_recv
            tx += c.bytes_sent
    return rx, tx


def publish(name, data):
    path = os.path.join(OUT, name)
    with open(path + ".tmp", "w") as f:
        json.dump(data, f, ensure_ascii=False)
        f.write("\n")
    os.replace(path + ".tmp", path)


def main():
    os.makedirs(OUT, exist_ok=True)
    gpu = GpuReader()
    gpu.start()
    cfg, cfg_time = load_config(), config_mtime()
    keys = ("cpu", "mem_used", "mem_cached", "mem_free", "net_down", "net_up")
    hist = {k: deque(maxlen=cfg["points"]) for k in keys}
    gpu_hist = {}  # index -> {"util": deque, "mem": deque}
    psutil.cpu_percent(interval=None)
    prev, prev_t = net_counters(), time.monotonic()
    time.sleep(1)

    while True:
        if config_mtime() != cfg_time:  # changed from the panel: apply and reset graphs
            cfg, cfg_time = load_config(), config_mtime()
            hist = {k: deque(maxlen=cfg["points"]) for k in keys}
            gpu_hist = {}
        cpu = psutil.cpu_percent(interval=None)
        f = psutil.cpu_freq()
        freq = f.current if f else 0
        vm = psutil.virtual_memory()
        used, free = vm.total - vm.available, vm.free
        cached = max(vm.total - used - free, 0)
        now, cur = time.monotonic(), net_counters()
        down = max(cur[0] - prev[0], 0) / (now - prev_t)
        up = max(cur[1] - prev[1], 0) / (now - prev_t)
        prev, prev_t = cur, now

        for k, v in (("cpu", cpu), ("mem_used", used), ("mem_cached", cached),
                     ("mem_free", free), ("net_down", down), ("net_up", up)):
            hist[k].append(v)
        gpus = dict(gpu.gpus)
        for idx, g in gpus.items():
            h = gpu_hist.setdefault(idx, {"util": deque(maxlen=cfg["points"]),
                                          "mem": deque(maxlen=cfg["points"])})
            h["util"].append(g["util"])
            h["mem"].append(g["mem_used"])

        publish("state.json", {
            **{k: list(v) for k, v in hist.items()},
            "freq": freq,
            "interval": cfg["interval"],
            "points": cfg["points"],
            "mem_total": vm.total,
            "gpus": {str(i): {"name": g["name"], "mem_total": g["mem_total"],
                              "util": list(gpu_hist[i]["util"]), "mem": list(gpu_hist[i]["mem"])}
                     for i, g in gpus.items()},
        })

        # lines for the collapsed numbers in the Quickshell corner (the panel has the graphs)
        publish("cpu.json", {
            "text": f"󰻠 {cpu:.0f}%",
            "tooltip": f"CPU {cpu:.0f}% at {freq / 1000:.1f} GHz",
        })
        publish("mem.json", {
            "text": f"󰍛 {fmt_bytes(used, short=True)} used  {fmt_bytes(free, short=True)} free",
            "tooltip": (f"Used {fmt_bytes(used)}\nCached {fmt_bytes(cached)}\n"
                        f"Free {fmt_bytes(free)}\nTotal {fmt_bytes(vm.total)}"),
        })
        # totals are since boot (the kernel's interface counters, all interfaces but lo)
        publish("net.json", {
            "text": f"󰇚 {fmt_bytes(down, short=True)} ({fmt_bytes(cur[0], short=True)})"
                    f"  󰕒 {fmt_bytes(up, short=True)} ({fmt_bytes(cur[1], short=True)})",
            "tooltip": (f"Down {fmt_bytes(down, True)}\nUp {fmt_bytes(up, True)}\n"
                        f"Total since boot: down {fmt_bytes(cur[0])}, up {fmt_bytes(cur[1])}"),
        })
        if gpus:
            parts = [f"{g['name'].replace('RTX ', '')} {g['util']:.0f}% {fmt_bytes(g['mem_used'], short=True)}"
                     for _, g in sorted(gpus.items())]
            publish("gpu.json", {
                "text": "󰢮 " + "  ".join(parts),
                "tooltip": "\n".join(
                    f"{g['name']}: {g['util']:.0f}% usage, "
                    f"{fmt_bytes(g['mem_used'])} / {fmt_bytes(g['mem_total'])}"
                    for _, g in sorted(gpus.items())),
            })
        deadline = time.monotonic() + cfg["interval"]
        while time.monotonic() < deadline and config_mtime() == cfg_time:
            time.sleep(0.1)


if __name__ == "__main__":
    main()
