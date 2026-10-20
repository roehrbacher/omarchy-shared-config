#!/usr/bin/env python3
"""Focus the window of an MPRIS player (any app, not just Spotify).

Usage: focus-player.py <dbus-name> <identity> <desktop-entry> <track-title>

1. PID owning the MPRIS bus name (org.freedesktop.DBus.GetConnectionUnixProcessID)
   -> Hyprland client with that PID, or one of its parent processes
   (browsers own MPRIS in the main process, which also owns the windows).
   Several windows (browser windows, PWAs): prefer the one whose title
   contains the track title (the tab or video title).
2. Fallback: client class / initialClass matching desktop entry or identity.
3. Spotify not running: start it (old behaviour).
"""
import json
import os
import subprocess
import sys


def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    except (OSError, subprocess.CalledProcessError):
        return ""


def bus_pid(name):
    if not name:
        return 0
    out = run(["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
               "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", name])
    parts = out.split()
    return int(parts[1]) if len(parts) == 2 and parts[1].isdigit() else 0


def ancestors(pid):
    seen = []
    while pid > 1 and pid not in seen:
        seen.append(pid)
        try:
            with open("/proc/%d/stat" % pid) as f:
                pid = int(f.read().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    return seen


def norm(s):
    return str(s or "").strip().lower()


def pick(cands, title):
    if not cands:
        return None
    t = norm(title)
    if t:
        for c in cands:
            if t in norm(c.get("title")):
                return c
    # Most recently focused first.
    return sorted(cands, key=lambda c: c.get("focusHistoryID", 1 << 30))[0]


def main():
    args = (sys.argv[1:] + ["", "", "", ""])[:4]
    dbus, identity, desktop, title = args
    try:
        clients = json.loads(run(["hyprctl", "clients", "-j"]) or "[]")
    except ValueError:
        clients = []
    clients = [c for c in clients if c.get("mapped", True) and c.get("address")]

    target = None
    pid = bus_pid(dbus)
    if pid:
        for p in ancestors(pid):
            target = pick([c for c in clients if c.get("pid") == p], title)
            if target:
                break

    if not target:
        keys = [k for k in (norm(desktop), norm(identity), norm(dbus).replace("org.mpris.mediaplayer2.", "").split(".")[0]) if k]
        for k in keys:
            target = pick([c for c in clients if k in (norm(c.get("class")), norm(c.get("initialClass")))
                           or k in norm(c.get("class"))], title)
            if target:
                break

    if target:
        cmd = 'hl.dsp.focus({ window = "address:%s" })' % target["address"]
        subprocess.call(["hyprctl", "dispatch", cmd], stdout=subprocess.DEVNULL)
        print("focused %s (%s)" % (target.get("class"), target["address"]))
    elif "spotify" in (norm(desktop), norm(identity)) or not (dbus or identity or desktop):
        subprocess.Popen(["omarchy-launch-spotify"], start_new_session=True)
        print("launched spotify")
    else:
        print("no window for player")


if __name__ == "__main__":
    main()
