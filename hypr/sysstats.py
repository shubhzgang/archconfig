#!/usr/bin/env python3
"""System stats panel: CPU, RAM (used/cached/free), network and NVIDIA GPU graphs.

Runs as a Wayland window with app_id "sysstats" so a pyprland scratchpad can
slide it in (see pyprland.toml). Colors come from the active pywal scheme.
History keeps sampling while the panel is hidden, so graphs are full on open.
"""
import json
import math
import os
import subprocess
import threading
import time
from collections import deque

import psutil
from PyQt6.QtCore import QPointF, QRectF, Qt, QTimer
from PyQt6.QtGui import (QColor, QFont, QGuiApplication, QLinearGradient,
                         QPainter, QPainterPath, QPen)
from PyQt6.QtWidgets import QApplication, QWidget

HISTORY = 120          # samples (1 per second)
TICK_MS = 1000
WAL_COLORS = os.path.expanduser("~/.cache/wal/colors.json")
FONT = "CodeNewRoman Nerd Font Mono"
PAD = 28
GAP = 26
HEADER_H = 40
LEGEND_H = 26


# ---- palette ---------------------------------------------------------------
class Palette:
    def __init__(self):
        self.mtime = 0
        self.load()

    def load(self):
        try:
            mtime = os.path.getmtime(WAL_COLORS)
            if mtime == self.mtime:
                return
            self.mtime = mtime
            with open(WAL_COLORS) as f:
                j = json.load(f)
            c = j["colors"]
            self.bg = QColor(j["special"]["background"])
            self.ink = QColor(c["color7"])
            self.muted = QColor(c["color8"])
            self.series = [QColor(c[f"color{i}"]) for i in range(1, 7)]
        except (OSError, KeyError, ValueError):
            if not hasattr(self, "bg"):
                self.bg = QColor("#101010")
                self.ink = QColor("#d8d8d8")
                self.muted = QColor("#808080")
                self.series = [QColor(h) for h in
                               ("#e06c75", "#61afef", "#98c379", "#e5c07b", "#c678dd", "#56b6c2")]


# ---- samplers --------------------------------------------------------------
class GpuReader(threading.Thread):
    """Keeps one persistent `nvidia-smi -l 1` running; no process spawn per tick."""

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


def fmt_bytes(n, rate=False):
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or unit == "TiB":
            s = f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
            return s + ("/s" if rate else "")
        n /= 1024


def nice_ceiling(v):
    if v <= 0:
        return 1
    mag = 10 ** math.floor(math.log10(v))
    for m in (1, 2, 5, 10):
        if v <= m * mag:
            return m * mag


# ---- widget ----------------------------------------------------------------
class Stats(QWidget):
    def __init__(self):
        super().__init__()
        self.pal = Palette()
        self.cpu = deque(maxlen=HISTORY)
        self.freq = 0
        self.mem_used = deque(maxlen=HISTORY)
        self.mem_cached = deque(maxlen=HISTORY)
        self.mem_free = deque(maxlen=HISTORY)
        self.mem_total = psutil.virtual_memory().total
        self.net_down = deque(maxlen=HISTORY)
        self.net_up = deque(maxlen=HISTORY)
        self.gpu_hist = {}  # index -> {"util": deque, "mem": deque}
        self.gpu_reader = GpuReader()
        self.gpu_reader.start()
        self._net_prev = self._net_counters()
        self._net_time = None
        psutil.cpu_percent(interval=None)

        self.setWindowTitle("System stats")
        self.resize(1152, 1728)
        timer = QTimer(self)
        timer.timeout.connect(self.sample)
        timer.start(TICK_MS)

    @staticmethod
    def _net_counters():
        rx = tx = 0
        for nic, c in psutil.net_io_counters(pernic=True).items():
            if nic != "lo":
                rx += c.bytes_recv
                tx += c.bytes_sent
        return rx, tx

    def sample(self):
        self.pal.load()
        self.cpu.append(psutil.cpu_percent(interval=None))
        f = psutil.cpu_freq()
        self.freq = f.current if f else 0

        vm = psutil.virtual_memory()
        self.mem_total = vm.total
        free = vm.free
        used = vm.total - vm.available
        self.mem_used.append(used)
        self.mem_free.append(free)
        self.mem_cached.append(max(vm.total - used - free, 0))

        now = time.monotonic()
        rx, tx = self._net_counters()
        if self._net_time is not None:
            dt = now - self._net_time
            self.net_down.append(max(rx - self._net_prev[0], 0) / dt)
            self.net_up.append(max(tx - self._net_prev[1], 0) / dt)
        self._net_prev = (rx, tx)
        self._net_time = now

        for idx, g in list(self.gpu_reader.gpus.items()):
            h = self.gpu_hist.setdefault(idx, {"util": deque(maxlen=HISTORY),
                                               "mem": deque(maxlen=HISTORY)})
            h["util"].append(g["util"])
            h["mem"].append(g["mem_used"])
        self.update()

    # ---- drawing helpers ----
    def font(self, px, bold=False):
        f = QFont(FONT)
        f.setPixelSize(px)
        f.setBold(bold)
        return f

    def text(self, p, x, y, s, color, px=16, bold=False, align=Qt.AlignmentFlag.AlignLeft,
             w=None):
        p.setFont(self.font(px, bold))
        p.setPen(color)
        rect = QRectF(x, y, w if w is not None else 2000, HEADER_H)
        if align == Qt.AlignmentFlag.AlignRight:
            rect = QRectF(x - (w or 0), y, w or 0, HEADER_H)
        p.drawText(rect, align | Qt.AlignmentFlag.AlignVCenter, s)

    def header(self, p, x, y, w, title, value, legend=()):
        """Title + current value in ink; legend swatches carry the series colors."""
        self.text(p, x, y, title, self.pal.ink, 20, True)
        self.text(p, x + w, y, value, self.pal.ink, 18, align=Qt.AlignmentFlag.AlignRight, w=w * 0.75)
        if legend:
            lx = x
            ly = y + HEADER_H - 4
            for label, color in legend:
                p.setPen(Qt.PenStyle.NoPen)
                p.setBrush(color)
                p.drawRoundedRect(QRectF(lx, ly + 5, 14, 6), 3, 3)
                self.text(p, lx + 22, ly - 8, label, self.pal.ink, 15)
                lx += 22 + 11 * len(label) + 26

    def plot(self, p, rect, ymax, ymax_label, series, stacked=False):
        """series: list of (deque, color). One shared y-axis starting at zero."""
        grid = QColor(self.pal.muted)
        grid.setAlpha(55)
        p.setPen(QPen(grid, 1))
        for frac in (0, 0.5, 1):
            y = rect.bottom() - rect.height() * frac
            p.drawLine(QPointF(rect.left(), y), QPointF(rect.right(), y))
        self.text(p, rect.left() + 4, rect.top() - 2, ymax_label, self.pal.muted, 13)

        step = rect.width() / (HISTORY - 1)

        def pt(i, n, v, base=0):
            x = rect.right() - (n - 1 - i) * step
            y = rect.bottom() - rect.height() * min((v + base) / ymax, 1)
            return QPointF(x, y)

        base_vals = None
        for dq, color in series:
            vals = list(dq)
            n = len(vals)
            if n < 2:
                continue
            bases = base_vals if (stacked and base_vals) else [0] * n
            top = [pt(i, n, v, bases[i]) for i, v in enumerate(vals)]
            bottom = [pt(i, n, 0, bases[i]) for i in range(n)]
            area = QPainterPath(top[0])
            for q in top[1:]:
                area.lineTo(q)
            for q in reversed(bottom):
                area.lineTo(q)
            area.closeSubpath()
            grad = QLinearGradient(0, rect.top(), 0, rect.bottom())
            hi, lo = QColor(color), QColor(color)
            hi.setAlpha(150 if stacked else 110)
            lo.setAlpha(150 if stacked else 8)
            grad.setColorAt(0, hi)
            grad.setColorAt(1, lo)
            p.setPen(Qt.PenStyle.NoPen)
            p.setBrush(grad)
            p.drawPath(area)
            line = QPainterPath(top[0])
            for q in top[1:]:
                line.lineTo(q)
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.setPen(QPen(color, 2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap,
                          Qt.PenJoinStyle.RoundJoin))
            p.drawPath(line)
            if stacked:
                base_vals = [b + v for b, v in zip(bases, vals)]

    def plot_mirrored(self, p, rect, ymax, label, up, down):
        """Network graph like macOS: received grows up from a center line, sent grows down."""
        grid = QColor(self.pal.muted)
        grid.setAlpha(55)
        mid = rect.center().y()
        p.setPen(QPen(grid, 1))
        for y in (rect.top(), rect.bottom()):
            p.drawLine(QPointF(rect.left(), y), QPointF(rect.right(), y))
        center = QColor(self.pal.muted)
        center.setAlpha(120)
        p.setPen(QPen(center, 1))
        p.drawLine(QPointF(rect.left(), mid), QPointF(rect.right(), mid))
        self.text(p, rect.left() + 4, rect.top() - 2, label, self.pal.muted, 13)
        self.text(p, rect.left() + 4, rect.bottom() - HEADER_H + 2, label, self.pal.muted, 13)

        step = rect.width() / (HISTORY - 1)
        half = rect.height() / 2
        for dq, color, sign in ((down, self.pal.series[3], -1), (up, self.pal.series[4], 1)):
            vals = list(dq)
            n = len(vals)
            if n < 2:
                continue
            pts = [QPointF(rect.right() - (n - 1 - i) * step,
                           mid + sign * half * min(v / ymax, 1)) for i, v in enumerate(vals)]
            area = QPainterPath(QPointF(pts[0].x(), mid))
            for q in pts:
                area.lineTo(q)
            area.lineTo(QPointF(pts[-1].x(), mid))
            area.closeSubpath()
            far = rect.top() if sign < 0 else rect.bottom()
            grad = QLinearGradient(0, far, 0, mid)
            hi, lo = QColor(color), QColor(color)
            hi.setAlpha(120)
            lo.setAlpha(8)
            grad.setColorAt(0, hi)
            grad.setColorAt(1, lo)
            p.setPen(Qt.PenStyle.NoPen)
            p.setBrush(grad)
            p.drawPath(area)
            line = QPainterPath(pts[0])
            for q in pts[1:]:
                line.lineTo(q)
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.setPen(QPen(color, 2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap,
                          Qt.PenJoinStyle.RoundJoin))
            p.drawPath(line)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        pal = self.pal
        p.fillRect(self.rect(), pal.bg)
        s = pal.series
        x, w = PAD, self.width() - 2 * PAD
        gpus = sorted(self.gpu_hist)

        weights = [1.0, 1.25, 1.0] + ([0.9] * len(gpus))
        total_gap = GAP * (len(weights) - 1)
        extras = [0, 0, LEGEND_H] + [0] * len(gpus)  # blocks with a legend row
        avail = self.height() - 2 * PAD - total_gap - HEADER_H * len(weights) - sum(extras)
        unit = avail / sum(weights)
        y = PAD

        def block(i):
            nonlocal y
            top = y
            y += HEADER_H + extras[i] + unit * weights[i] + GAP
            return top, QRectF(x, top + HEADER_H + extras[i] + 14, w, unit * weights[i] - 14)

        # CPU
        top, r = block(0)
        cpu_now = self.cpu[-1] if self.cpu else 0
        self.header(p, x, top, w, "CPU", f"{cpu_now:.0f}%   {self.freq / 1000:.1f} GHz")
        self.plot(p, r, 100, "100%", [(self.cpu, s[0])])

        # Memory: used / cached / free as separate graphs on a shared 0..total scale
        top, r = block(1)
        third = (w - 2 * GAP) / 3
        mem = [("used", self.mem_used, s[1]), ("cached", self.mem_cached, s[2]),
               ("free", self.mem_free, pal.ink)]
        for k, (label, dq, color) in enumerate(mem):
            cx = x + k * (third + GAP)
            self.header(p, cx, top, third, f"RAM {label}", fmt_bytes(dq[-1] if dq else 0))
            self.plot(p, QRectF(cx, r.top(), third, r.height()), self.mem_total,
                      fmt_bytes(self.mem_total), [(dq, color)])

        # Network
        top, r = block(2)
        down = self.net_down[-1] if self.net_down else 0
        up = self.net_up[-1] if self.net_up else 0
        peak = max(list(self.net_down) + list(self.net_up) + [100 * 1024])
        ymax = nice_ceiling(peak * 1.1)
        self.header(p, x, top, w, "Network", "",
                    legend=[(f"down {fmt_bytes(down, True)}", s[3]),
                            (f"up {fmt_bytes(up, True)}", s[4])])
        self.plot_mirrored(p, r, ymax, fmt_bytes(ymax, True), self.net_up, self.net_down)

        # GPUs: usage | memory side by side
        half = (w - GAP) / 2
        for n, idx in enumerate(gpus):
            g = self.gpu_reader.gpus.get(idx, {})
            hist = self.gpu_hist[idx]
            top, r = block(3 + n)
            name = g.get("name", f"GPU {idx}")
            u = hist["util"][-1] if hist["util"] else 0
            m = hist["mem"][-1] if hist["mem"] else 0
            mt = g.get("mem_total", 1)
            self.header(p, x, top, half, f"{name} usage", f"{u:.0f}%")
            self.header(p, x + half + GAP, top, half, f"{name} memory",
                        f"{fmt_bytes(m)} / {fmt_bytes(mt)}")
            left = QRectF(r.left(), r.top(), half, r.height())
            right = QRectF(r.left() + half + GAP, r.top(), half, r.height())
            self.plot(p, left, 100, "100%", [(hist["util"], s[5])])
            self.plot(p, right, mt, fmt_bytes(mt), [(hist["mem"], s[1])])


def main():
    os.environ.setdefault("QT_QPA_PLATFORM", "wayland")
    QGuiApplication.setDesktopFileName("sysstats")
    app = QApplication([])
    w = Stats()
    w.show()
    app.exec()


if __name__ == "__main__":
    main()
