#!/usr/bin/env python3
"""Load the readout QML offscreen, check sizes, and save a PNG."""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt6.QtCore import QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlComponent, QQmlEngine
from PyQt6.QtQuick import QQuickWindow

HERE = os.path.dirname(os.path.abspath(__file__))
QML = os.path.join(HERE, "Readout.qml")
OUT = os.environ.get("POWER_READOUT_PNG", "/tmp/power-readout.png")


def num(report, key):
    for line in report.splitlines():
        if line.startswith(key + " "):
            return float(line.split()[1])
    raise SystemExit(f"missing {key} in report:\n{report}")


def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlEngine()
    component = QQmlComponent(engine, QUrl.fromLocalFile(QML))
    if component.isError():
        print(component.errorString(), file=sys.stderr)
        return 1
    win = component.create()
    if win is None:
        print(component.errorString(), file=sys.stderr)
        return 1
    win.show()
    app.processEvents()
    report = str(win.property("report") or "")
    print(report)
    fail = 0

    def check(cond, msg):
        nonlocal fail
        print(("ok   " if cond else "FAIL ") + msg)
        if not cond:
            fail = 1

    pc_slot = num(report, "pc-broken-slot")
    pc_ink = num(report, "pc-broken-ink-h")
    pc_w = num(report, "pc-fixed-w")
    pc_h = num(report, "pc-fixed-h")
    xps_broken = num(report, "xps-broken-slot")
    xps_w = num(report, "xps-fixed-w")
    xps_h = num(report, "xps-fixed-h")
    check(pc_ink < 10, f"64W optical ink is tiny ({pc_ink:.1f}px)")
    check(pc_h >= 11, f"64W label is readable ({pc_h:.1f}px)")
    check(pc_w < pc_slot, f"64W slot shrinks ({pc_w:.0f} < {pc_slot:.0f})")
    check(xps_broken == 81, "old XPS watts slot is 3 icon slots")
    check(xps_h >= 11, f"XPS label is readable ({xps_h:.1f}px)")
    check(xps_w < xps_broken + 20, f"XPS width stays near the text ({xps_w:.0f})")
    check(num(report, "nobattery") == 0, "no battery takes no width")
    if not isinstance(win, QQuickWindow):
        print(f"FAIL window type {type(win)}", file=sys.stderr)
        return 1
    image = win.grabWindow()
    if image.isNull() or image.width() < 100:
        print("FAIL grab produced no image", file=sys.stderr)
        return 1
    os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
    if not image.save(OUT):
        print(f"FAIL could not save {OUT}", file=sys.stderr)
        return 1
    print(f"wrote {OUT} {image.width()}x{image.height()}")
    return fail


if __name__ == "__main__":
    sys.exit(main())
