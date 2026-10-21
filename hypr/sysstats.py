#!/usr/bin/env python3
"""System stats panel: CPU, RAM (used/cached/free), network and NVIDIA GPU graphs.

Runs as a Wayland window with app_id "sysstats" so a pyprland scratchpad can
slide it in (see pyprland.toml). Colors come from the active pywal scheme.
Samples and history come from sysstatsd.py (state.json), which also feeds
waybar, so graphs are full as soon as the panel opens.
"""
import json
import math
import os
import subprocess
from PyQt6.QtCore import QPointF, QRectF, Qt, QTimer
from PyQt6.QtGui import (QColor, QFont, QGuiApplication, QLinearGradient,
                         QPainter, QPainterPath, QPen)
from PyQt6.QtWidgets import QApplication, QWidget

CONFIG = os.path.expanduser("~/.config/hypr/sysstats.json")
INTERVALS = [1, 2, 3, 5, 10]      # seconds between samples
POINTS = [30, 60, 120, 240, 360, 480, 600]    # samples kept per graph
CONTROLS_H = 40
TICK_MS = 1000
WAL_COLORS = os.path.expanduser("~/.cache/wal/colors.json")
STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "sysstats", "state.json")
FONT = "CodeNewRoman Nerd Font Mono"
PAD = 28
CARD_PAD = 16     # inside each card
CARD_GAP = 20     # between cards
ROW_GAP = 10      # between graphs inside a card
HEADER_H = 34
LEGEND_H = 26


# ---- palette ---------------------------------------------------------------
def mix(a, b, t):
    """a moved t of the way toward b."""
    return QColor(*[round(x + (y - x) * t) for x, y in zip(a.getRgb()[:3], b.getRgb()[:3])])


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
            # Window: gradient from lighter color1 (active border) to lighter color2 (inactive border); cards: fixed light grey.
            # Everything drawn on them is dark, so it stays readable on any wallpaper.
            self.panel = mix(QColor(c["color2"]), QColor("white"), 0.35)
            self.panel_start = mix(QColor(c["color1"]), QColor("white"), 0.35)
            self.card = QColor("#c3cadb")  # fixed light grey with a slight blue tint
            self.ink = self.bg
            self.muted = mix(self.ink, self.card, 0.45)
            self.series = [mix(QColor(c[f"color{i}"]), QColor("black"), 0.4) for i in range(1, 7)]
        except (OSError, KeyError, ValueError):
            if not hasattr(self, "bg"):
                self.bg = QColor("#101010")
                self.ink = QColor("#101010")
                self.muted = QColor("#506070")
                self.panel = QColor("#9ab0c8")
                self.panel_start = QColor("#b4a0c8")
                self.card = QColor("#c3cadb")
                self.series = [QColor(h) for h in
                               ("#a03c45", "#2d6fb0", "#5a8a3a", "#a07a2a", "#8a3aa0", "#2a8a96")]


def fmt_bytes(n, rate=False):
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or unit == "TiB":
            s = f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
            return s + ("/s" if rate else "")
        n /= 1024


def fmt_ago(seconds):
    seconds = int(round(seconds))
    mins, secs = divmod(seconds, 60)
    if not mins:
        return f"-{secs}s"
    return f"-{mins}m" if not secs else f"-{mins}m {secs:02d}s"


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
        self.cpu = []
        self.freq = 0
        self.mem_used = []
        self.mem_cached = []
        self.mem_free = []
        self.mem_total = 1
        self.net_down = []
        self.net_up = []
        self.interval, self.points = 1, 120
        self.chips = []     # (QRectF, config key, value) for hit-testing clicks
        self.gpus = {}      # index -> {"name", "mem_total"}
        self.gpu_hist = {}  # index -> {"util": [...], "mem": [...]}

        self.setWindowTitle("System stats")
        self.resize(1152, 1728)
        self.setMouseTracking(True)
        timer = QTimer(self)
        timer.timeout.connect(self.sample)
        timer.start(TICK_MS)
        self.sample()

    def sample(self):
        self.pal.load()
        try:
            with open(STATE) as f:
                st = json.load(f)
        except (OSError, ValueError):
            return  # sysstatsd not running yet; keep the last frame
        self.interval, self.points = st["interval"], st["points"]
        self.cpu, self.freq = st["cpu"], st["freq"]
        self.mem_used, self.mem_cached, self.mem_free = st["mem_used"], st["mem_cached"], st["mem_free"]
        self.mem_total = st["mem_total"]
        self.net_down, self.net_up = st["net_down"], st["net_up"]
        self.gpus = {int(i): {"name": g["name"], "mem_total": g["mem_total"]}
                     for i, g in st["gpus"].items()}
        self.gpu_hist = {int(i): {"util": g["util"], "mem": g["mem"]} for i, g in st["gpus"].items()}
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

        step = rect.width() / (self.points - 1)
        quarter = max(self.points // 4, 1)  # vertical guides at 1/4 of the window
        p.setPen(QPen(grid, 1))
        for k in range(quarter, self.points, quarter):
            vx = rect.right() - k * step
            p.drawLine(QPointF(vx, rect.top()), QPointF(vx, rect.bottom()))
        self.time_labels(p, rect, step, quarter)

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

    def plot_mirrored(self, p, rect, up, down):
        """Network graph like macOS: received grows up from a center line, sent grows down.
        Each half has its own auto-scale, labeled at its outer edge."""
        floor = 100 * 1024
        scales = {id(down): nice_ceiling(max(list(down) + [floor]) * 1.1),
                  id(up): nice_ceiling(max(list(up) + [floor]) * 1.1)}
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
        self.text(p, rect.left() + 4, rect.top() - 2, fmt_bytes(scales[id(down)], True), self.pal.muted, 13)
        self.text(p, rect.left() + 4, rect.bottom() - HEADER_H + 2, fmt_bytes(scales[id(up)], True),
                  self.pal.muted, 13)

        step = rect.width() / (self.points - 1)
        quarter = max(self.points // 4, 1)  # vertical guides at 1/4 of the window
        p.setPen(QPen(grid, 1))
        for k in range(quarter, self.points, quarter):
            vx = rect.right() - k * step
            p.drawLine(QPointF(vx, rect.top()), QPointF(vx, rect.bottom()))
        self.time_labels(p, rect, step, quarter)
        half = rect.height() / 2
        for dq, color, sign in ((down, self.pal.series[3], -1), (up, self.pal.series[4], 1)):
            vals = list(dq)
            n = len(vals)
            if n < 2:
                continue
            ymax = scales[id(dq)]
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

    def time_labels(self, p, rect, step, quarter):
        """Small 'time ago' labels centered under each vertical guide line."""
        for k in range(quarter, self.points, quarter):
            self.text(p, rect.right() - k * step - 30, rect.bottom() - 9, fmt_ago(k * self.interval),
                      self.pal.muted, 12, align=Qt.AlignmentFlag.AlignHCenter, w=60)

    # ---- controls: sampling interval and history length ----
    def draw_controls(self, p, x, y, w):
        self.chips = []
        pal = self.pal
        cx = x
        span = self.interval * self.points
        for label, key, values, fmt in (("every", "interval", INTERVALS, lambda v: f"{v}s"),
                                        ("points", "points", POINTS, str)):
            self.text(p, cx, y, label, pal.ink, 15)
            cx += 11 * len(label) + 14
            for v in values:
                text = fmt(v)
                cw = 11 * len(text) + 22
                rect = QRectF(cx, y + 5, cw, 26)
                on = v == (self.interval if key == "interval" else self.points)
                p.setPen(Qt.PenStyle.NoPen if on else QPen(pal.muted, 1))
                p.setBrush(pal.series[0] if on else Qt.BrushStyle.NoBrush)
                p.drawRoundedRect(rect, 8, 8)
                self.text(p, rect.left(), y, text, pal.panel if on else pal.ink, 15,
                          align=Qt.AlignmentFlag.AlignHCenter, w=cw)
                self.chips.append((rect, key, v))
                cx += cw + 6
            cx += 24
        mins, secs = divmod(int(round(span)), 60)
        self.text(p, x + w, y, f"last {mins}m {secs:02d}s" if mins else f"last {secs}s",
                  pal.ink, 16, align=Qt.AlignmentFlag.AlignRight, w=w * 0.4)

    def keyPressEvent(self, e):
        if e.key() == Qt.Key.Key_Escape:  # hide the scratchpad, same as pushing the left edge again
            subprocess.Popen(["pypr", "toggle", "taskbar"])
        else:
            super().keyPressEvent(e)

    def mouseMoveEvent(self, e):
        over = any(r.contains(e.position()) for r, _, _ in self.chips)
        self.setCursor(Qt.CursorShape.PointingHandCursor if over else Qt.CursorShape.ArrowCursor)

    def mouseReleaseEvent(self, e):
        for rect, key, value in self.chips:
            if rect.contains(e.position()):
                try:
                    with open(CONFIG) as f:
                        cfg = json.load(f)
                except (OSError, ValueError):
                    cfg = {"interval": self.interval, "points": self.points}
                cfg[key] = value
                with open(CONFIG + ".tmp", "w") as f:
                    json.dump(cfg, f, indent=2)
                os.replace(CONFIG + ".tmp", CONFIG)  # sysstatsd applies it and resets the graphs
                return

    def draw_card(self, p, rect):
        """Light grey card with a spread-out dark shadow."""
        p.setPen(Qt.PenStyle.NoPen)
        for i in range(11, 0, -1):  # stacked translucent rounded rects fake the blurred shadow
            p.setBrush(QColor(0, 0, 0, 5))
            p.drawRoundedRect(rect.adjusted(-i, -i + 3, i, i + 3), 10 + i, 10 + i)
        p.setBrush(self.pal.card)
        p.drawRoundedRect(rect, 10, 10)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        pal = self.pal
        bg = QLinearGradient(0, 0, self.width(), self.height())  # background only; cards stay flat
        bg.setColorAt(0, pal.panel_start)
        bg.setColorAt(1, pal.panel)
        p.fillRect(self.rect(), bg)
        s = pal.series
        x, w = PAD, self.width() - 2 * PAD
        gpus = sorted(self.gpu_hist)
        self.draw_controls(p, x, PAD, w)

        def last(dq):
            return dq[-1] if dq else 0

        # Cards: one raised box per device. Each row is (weight, legend?, draw(top, rect)),
        # one full-width graph per row so the shared time axis lines up vertically.
        cards = []

        def cpu_row(top, r):
            self.header(p, r.left(), top, r.width(), "CPU",
                        f"{last(self.cpu):.0f}%   {self.freq / 1000:.1f} GHz")
            self.plot(p, r, 100, "100%", [(self.cpu, s[4])])
        cards.append([(1.0, False, cpu_row)])

        # RAM used / cached / free share the 0..total scale so heights compare directly
        ram = []
        for label, dq, color in (("used", self.mem_used, s[1]), ("cached", self.mem_cached, s[2]),
                                 ("free", self.mem_free, pal.ink)):
            def mem_row(top, r, label=label, dq=dq, color=color):
                self.header(p, r.left(), top, r.width(), f"RAM {label}", fmt_bytes(last(dq)))
                self.plot(p, r, self.mem_total, fmt_bytes(self.mem_total), [(dq, color)])
            ram.append((0.8, False, mem_row))
        cards.append(ram)

        def net_row(top, r):
            self.header(p, r.left(), top, r.width(), "Network", "",
                        legend=[(f"down {fmt_bytes(last(self.net_down), True)}", s[3]),
                                (f"up {fmt_bytes(last(self.net_up), True)}", s[4])])
            self.plot_mirrored(p, r, self.net_up, self.net_down)
        cards.append([(1.3, True, net_row)])

        for idx in gpus:
            g = self.gpus.get(idx, {})
            hist = self.gpu_hist[idx]
            name = g.get("name", f"GPU {idx}")
            mt = g.get("mem_total", 1)

            def usage_row(top, r, name=name, hist=hist):
                self.header(p, r.left(), top, r.width(), f"{name} usage", f"{last(hist['util']):.0f}%")
                self.plot(p, r, 100, "100%", [(hist["util"], s[5])])

            def memory_row(top, r, name=name, hist=hist, mt=mt):
                self.header(p, r.left(), top, r.width(), f"{name} memory",
                            f"{fmt_bytes(last(hist['mem']))} / {fmt_bytes(mt)}")
                self.plot(p, r, mt, fmt_bytes(mt), [(hist["mem"], s[1])])
            cards.append([(0.8, False, usage_row), (0.8, False, memory_row)])

        rows_all = [row for card in cards for row in card]
        fixed = (2 * PAD + CONTROLS_H + CARD_GAP * (len(cards) - 1) + 2 * CARD_PAD * len(cards)
                 + ROW_GAP * (len(rows_all) - len(cards)) + HEADER_H * len(rows_all)
                 + sum(LEGEND_H for _, legend, _ in rows_all if legend))
        unit = (self.height() - fixed) / sum(row[0] for row in rows_all)
        y = PAD + CONTROLS_H
        for card in cards:
            card_h = (2 * CARD_PAD + ROW_GAP * (len(card) - 1)
                      + sum(HEADER_H + (LEGEND_H if legend else 0) + unit * weight
                            for weight, legend, _ in card))
            self.draw_card(p, QRectF(x, y, w, card_h))
            ry = y + CARD_PAD
            for weight, legend, draw in card:
                extra = LEGEND_H if legend else 0
                height = unit * weight
                draw(ry, QRectF(x + CARD_PAD, ry + HEADER_H + extra + 10, w - 2 * CARD_PAD, height - 10))
                ry += HEADER_H + extra + height + ROW_GAP
            y += card_h + CARD_GAP


def main():
    os.environ.setdefault("QT_QPA_PLATFORM", "wayland")
    QGuiApplication.setDesktopFileName("sysstats")
    app = QApplication([])
    w = Stats()
    w.show()
    app.exec()


if __name__ == "__main__":
    main()
