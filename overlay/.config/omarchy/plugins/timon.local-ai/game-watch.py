#!/usr/bin/env python3
"""timon.local-ai game watcher: one notification when a game starts while a
local model is loaded; clicking it unloads the model.

Event-based: it sleeps on Hyprland's event socket and only looks around when a
window opens or closes (no polling). A game counts as running when a process
matches GAME_PATTERN (same as omarchy-safe-gate: Steam/Proton/Overwatch) or a
window class is steam_app_*. It notifies once per game session: again only
after every game has closed. Nothing happens while no model runs.

  game-watch.py            run (systemd user service local-ai-game-watch)
  game-watch.py --check    one check now, as if a window had just opened
Env for tests: LOCAL_AI_GAME_PATTERN, LOCAL_AI_HELPER, LOCAL_AI_HYPR_SOCKET, LOCAL_AI_DRY=1 (print
the notify-send command instead of sending it).
"""
import glob, json, os, socket, subprocess, sys, time

HERE = os.path.dirname(os.path.realpath(__file__))
HELPER = os.environ.get("LOCAL_AI_HELPER", os.path.join(HERE, "local-ai.py"))
GAME_PATTERN = os.environ.get("LOCAL_AI_GAME_PATTERN", "SteamLaunch|steam-launch-wrapper|proton |Overwatch")
DRY = os.environ.get("LOCAL_AI_DRY") == "1"
SETTLE = 3  # s after a window event, so a game's launcher chain is up


def log(msg):
    print(f"local-ai-game-watch: {msg}", file=sys.stderr, flush=True)


def run(*args, timeout=10):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except Exception as exc:  # noqa: BLE001
        return subprocess.CompletedProcess(args, 1, "", str(exc))


def gaming():
    if run("pgrep", "-f", GAME_PATTERN).returncode == 0:
        return True
    out = run("hyprctl", "clients", "-j").stdout
    try:
        return any(str(c.get("class", "")).startswith("steam_app_") for c in json.loads(out or "[]"))
    except ValueError:
        return False


def loaded_models():
    out = run(sys.executable, HELPER, "state").stdout
    try:
        models = json.loads(out).get("models", [])
    except ValueError:
        return []
    return [m for m in models if m.get("state") in ("on", "loading")]


def notify(models):
    names = " + ".join(short(m["name"]) for m in models)
    units = [m["unit"] for m in models]
    argv = ["systemctl", "--user", "stop", "--no-block", *units]
    cmd = ["notify-send", "-a", "Local AI", "-h", "string:omarchy-glyph:\U000f0bc6",
           "-h", "string:omarchy-exec-argv:" + json.dumps(argv), "-t", "15000",
           f"Local AI loaded · {names}"]
    if DRY:
        print("NOTIFY " + json.dumps(cmd), flush=True)
    else:
        run(*cmd)
    log(f"notified: {names}")


def short(name):
    # "Qwen3.6 35B-A3B" -> "Qwen3.6 35B" (keeps it short and scannable)
    parts = str(name).split()
    return " ".join(p.split("-")[0] if i else p for i, p in enumerate(parts)) or name


class Watcher:
    def __init__(self):
        self.notified = False  # for the current game session

    def check(self):
        if not gaming():
            if self.notified:
                log("game closed")
            self.notified = False
            return
        if self.notified:
            return
        models = loaded_models()
        self.notified = True  # once per game, also when no model runs now
        if models:
            notify(models)


def socket_path():
    if os.environ.get("LOCAL_AI_HYPR_SOCKET"):
        return os.environ["LOCAL_AI_HYPR_SOCKET"]
    rt = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    path = f"{rt}/hypr/{sig}/.socket2.sock"
    if sig and os.path.exists(path):
        return path
    found = sorted(glob.glob(f"{rt}/hypr/*/.socket2.sock"), key=os.path.getmtime)
    return found[-1] if found else ""


def main():
    w = Watcher()
    if "--check" in sys.argv:
        w.check()
        return
    w.check()  # a game already running at start counts as notified-or-not now
    while True:
        path = socket_path()
        if not path:
            time.sleep(10)
            continue
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(path)
            buf = b""
            due = None
            while True:
                s.settimeout(max(0.1, due - time.monotonic()) if due else None)
                try:
                    chunk = s.recv(4096)
                except socket.timeout:
                    due = None
                    w.check()
                    continue
                if not chunk:
                    break
                buf += chunk
                *lines, buf = buf.split(b"\n")
                if any(l.startswith((b"openwindow>>", b"closewindow>>")) for l in lines):
                    due = due or time.monotonic() + SETTLE
        except OSError as exc:
            log(f"socket: {exc}")
        time.sleep(5)


if __name__ == "__main__":
    main()
