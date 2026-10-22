#!/usr/bin/env python3
"""timon.local-ai watcher: notices while a local model is loaded; click one to
unload the model.

1. Game start (event-based, Hyprland window events): a process matches
   GAME_PATTERN (same as omarchy-safe-gate) or a steam_app_* window appears
   -> "Local AI loaded · <model>". Once per game session.
2. Competition (only while a model is loaded, cheap /proc + sysfs reads every
   TICK s): another app holding > VRAM_ON of VRAM or > BUSY_ON of a GPU engine,
   or available RAM below RAM_ON (blamed on the biggest non-model app), for
   SUSTAIN s -> "Local AI competing with <app>". Hysteresis: the timer resets
   only once the app drops below the *_OFF values. Once per app per model
   session (reset when the model unloads). Skipped while a game runs (1.
   already covered it). The model's own processes never count.

  game-watch.py            run (systemd user service local-ai-game-watch)
  game-watch.py --check    one game check now
  game-watch.py --sample   print one reading of the current GPU/RAM values
Env for tests: LOCAL_AI_HELPER, LOCAL_AI_GAME_PATTERN, LOCAL_AI_HYPR_SOCKET,
LOCAL_AI_PROC, LOCAL_AI_SYS_DRM, LOCAL_AI_MODEL_PIDS (space list, "" = none),
LOCAL_AI_TICK, LOCAL_AI_DRY=1 (print notify-send instead of sending).
"""
import glob, json, os, re, socket, subprocess, sys, time

HERE = os.path.dirname(os.path.realpath(__file__))
HELPER = os.environ.get("LOCAL_AI_HELPER", os.path.join(HERE, "local-ai.py"))
GAME_PATTERN = os.environ.get("LOCAL_AI_GAME_PATTERN", "SteamLaunch|steam-launch-wrapper|proton |Overwatch")
DRY = os.environ.get("LOCAL_AI_DRY") == "1"
PROC = os.environ.get("LOCAL_AI_PROC", "/proc")
SYS_DRM = os.environ.get("LOCAL_AI_SYS_DRM", "/sys/class/drm")
SETTLE = 3                                  # s after a window event
TICK = float(os.environ.get("LOCAL_AI_TICK", "5"))
GIB = 1 << 30
VRAM_ON, VRAM_OFF = 2 * GIB, int(1.5 * GIB)  # another app's VRAM
BUSY_ON, BUSY_OFF = 30.0, 20.0              # % of one GPU engine
RAM_ON, RAM_OFF = 3 * GIB, 4 * GIB          # MemAvailable
SUSTAIN = 20                                # s over the threshold
IGNORE = {"Hyprland", "Xwayland", "quickshell", "qs", ".quickshell-wra"}  # compositor/shell
GLYPH = "\U000f0bc6"                         # the widget's skull


def log(msg):
    print(f"local-ai-game-watch: {msg}", file=sys.stderr, flush=True)


def run(*args, timeout=10):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except Exception as exc:  # noqa: BLE001
        return subprocess.CompletedProcess(args, 1, "", str(exc))


def read(path):
    try:
        with open(path) as fh:
            return fh.read()
    except OSError:
        return ""


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


def short(name):
    # "Qwen3.6 35B-A3B" -> "Qwen3.6 35B"
    parts = str(name).split()
    return " ".join(p.split("-")[0] if i else p for i, p in enumerate(parts)) or name


def notify(summary, units):
    argv = ["systemctl", "--user", "stop", "--no-block", *units]
    cmd = ["notify-send", "-a", "Local AI", "-h", "string:omarchy-glyph:" + GLYPH,
           "-h", "string:omarchy-exec-argv:" + json.dumps(argv), "-t", "15000",
           summary, "Click to unload"]
    if DRY:
        print("NOTIFY " + json.dumps(cmd, ensure_ascii=False), flush=True)
    else:
        run(*cmd)
    log(f"notified: {summary}")


# ------------------------------------------------------------ resources
def app_slice():
    m = re.search(r"^0::(/.*)$", read(f"/proc/{os.getpid()}/cgroup"), re.M)
    return "/sys/fs/cgroup" + os.path.dirname(m.group(1)) if m else ""


class Models:
    """Which model units exist (helper, refreshed every 5 min) and their PIDs
    (the unit's cgroup.procs: one cheap read per tick)."""

    def __init__(self):
        self.units, self.names, self.at = [], {}, -1e9
        self.slice = app_slice()

    def refresh(self):
        if time.monotonic() - self.at < 300:
            return
        self.at = time.monotonic()
        out = run(sys.executable, HELPER, "state").stdout
        try:
            models = json.loads(out).get("models", [])
        except ValueError:
            return
        self.units = [m["unit"] for m in models]
        self.names = {m["unit"]: m.get("name", m["unit"]) for m in models}

    def active(self):
        """{unit: set(pids)} of running model units."""
        if "LOCAL_AI_MODEL_PIDS" in os.environ:
            pids = {int(p) for p in os.environ["LOCAL_AI_MODEL_PIDS"].split()}
            return {"test-model.service": pids} if pids else {}
        self.refresh()
        out = {}
        for u in self.units:
            pids = {int(p) for p in read(f"{self.slice}/{u}/cgroup.procs").split()}
            if pids:
                out[u] = pids
        return out


UNIT_RE = {"KiB": 1 << 10, "MiB": 1 << 20, "GiB": 1 << 30, "": 1}


def size(value):
    m = re.match(r"\s*(\d+)\s*(\w*)", value)
    return int(m.group(1)) * UNIT_RE.get(m.group(2), 1) if m else 0


def drm_clients():
    """{(pdev, client-id): (pid, vram_bytes, {engine: ns})} from /proc/*/fdinfo."""
    clients = {}
    for pid in os.listdir(PROC):
        if not pid.isdigit():
            continue
        fddir = f"{PROC}/{pid}/fd"
        try:
            fds = os.listdir(fddir)
        except OSError:
            continue
        for fd in fds:
            try:
                if not os.readlink(f"{fddir}/{fd}").startswith("/dev/dri/"):
                    continue
            except OSError:
                continue
            info = dict(l.split(":", 1) for l in read(f"{PROC}/{pid}/fdinfo/{fd}").splitlines() if ":" in l)
            cid = info.get("drm-client-id", "").strip()
            if not cid:
                continue
            key = (info.get("drm-pdev", "").strip(), cid)
            if key in clients:
                continue
            vram = size(info.get("drm-resident-vram") or info.get("drm-memory-vram") or "0")
            eng = {k[11:]: size(v) for k, v in info.items() if k.startswith("drm-engine-") and "capacity" not in k}
            clients[key] = (int(pid), vram, eng)
    return clients


def comm(pid):
    return read(f"{PROC}/{pid}/comm").strip()


def nice(name):
    return name[:1].upper() + name[1:] if name else "?"


def mem_available():
    m = re.search(r"^MemAvailable:\s+(\d+) kB", read(f"{PROC}/meminfo"), re.M)
    return int(m.group(1)) * 1024 if m else None


def biggest_rss(skip):
    best, name = 0, ""
    for pid in os.listdir(PROC):
        if not pid.isdigit() or int(pid) in skip:
            continue
        m = re.search(r"^VmRSS:\s+(\d+) kB", read(f"{PROC}/{pid}/status"), re.M)
        if m and int(m.group(1)) > best:
            best, name = int(m.group(1)), comm(pid)
    return name


def descendants(pids):
    """Model PIDs plus their children (llama.cpp may fork helpers)."""
    out = set(pids)
    if not out:
        return out
    parent = {}
    for pid in os.listdir(PROC):
        if pid.isdigit():
            m = re.search(r"^PPid:\s+(\d+)", read(f"{PROC}/{pid}/status"), re.M)
            if m:
                parent[int(pid)] = int(m.group(1))
    grew = True
    while grew:
        grew = False
        for p, pp in parent.items():
            if pp in out and p not in out:
                out.add(p)
                grew = True
    return out


def gpu_totals():
    out = []
    for dev in sorted(glob.glob(f"{SYS_DRM}/card[0-9]*/device")):
        used = read(f"{dev}/mem_info_vram_used").strip()
        if used:
            out.append({"card": dev.split("/")[-2], "vramUsed": int(used),
                        "vramTotal": int(read(f"{dev}/mem_info_vram_total").strip() or 0),
                        "busy": int(read(f"{dev}/gpu_busy_percent").strip() or 0)})
    return out


class Competition:
    def __init__(self):
        self.prev = {}           # (pdev,cid) -> (t, {engine: ns})
        self.since = {}          # app -> first time over the threshold
        self.notified = set()    # apps notified this model session
        self.ram_since = None

    def reset(self):
        self.__init__()

    def sample(self, model_pids, now):
        """[(app, why)] over threshold right now; also updates self.prev."""
        skip = descendants(model_pids)
        per_app = {}
        cur = drm_clients()
        for key, (pid, vram, eng) in cur.items():
            name = comm(pid)
            if pid in skip or name in IGNORE:
                continue
            busy = 0.0
            if key in self.prev:
                t0, e0 = self.prev[key]
                dt = (now - t0) * 1e9
                if dt > 0:
                    busy = max([(ns - e0.get(k, ns)) / dt * 100 for k, ns in eng.items()] or [0])
            a = per_app.setdefault(name, [0, 0.0])
            a[0] += vram
            a[1] = max(a[1], busy)
        self.prev = {k: (now, v[2]) for k, v in cur.items()}
        return per_app, skip

    def tick(self, models, now):
        per_app, skip = self.sample(set().union(*models.values()), now)
        hits = []
        for app, (vram, busy) in per_app.items():
            over = vram > VRAM_ON or busy > BUSY_ON
            under = vram < VRAM_OFF and busy < BUSY_OFF
            if over:
                self.since.setdefault(app, now)
            elif under:
                self.since.pop(app, None)
            if app in self.since and now - self.since[app] >= SUSTAIN:
                hits.append(app)
        for app in list(self.since):
            if app not in per_app:
                self.since.pop(app)
        avail = mem_available()
        if avail is not None:
            if avail < RAM_ON:
                if self.ram_since is None:
                    self.ram_since = now
            elif avail > RAM_OFF:
                self.ram_since = None
            if self.ram_since and now - self.ram_since >= SUSTAIN:
                app = biggest_rss(skip)
                if app and app not in IGNORE:
                    hits.append(app)
        for app in hits:
            if app not in self.notified:
                self.notified.add(app)
                notify(f"Local AI competing with {nice(app)}", sorted(models))


# ------------------------------------------------------------ main loop
class Watcher:
    def __init__(self):
        self.notified = False  # for the current game session
        self.models = Models()
        self.comp = Competition()
        self.was_loaded = False

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
            notify("Local AI loaded · " + " + ".join(short(m["name"]) for m in models),
                   [m["unit"] for m in models])

    def tick(self):
        active = self.models.active()
        if not active:
            if self.was_loaded:
                self.comp.reset()
            self.was_loaded = False
            return
        self.was_loaded = True
        if self.notified:  # a game runs: the game notice covers it
            return
        self.comp.tick(active, time.monotonic())


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
    if "--sample" in sys.argv:
        c, m = Competition(), Models()
        act = m.active()
        pids = set().union(*act.values()) if act else set()
        c.sample(pids, time.monotonic()); time.sleep(1)
        per_app, skip = c.sample(pids, time.monotonic())
        print(json.dumps({"modelUnits": sorted(act), "modelPids": sorted(skip), "gpus": gpu_totals(),
                          "memAvailableGiB": round((mem_available() or 0) / GIB, 2),
                          "apps": {a: {"vramMiB": v // (1 << 20), "busyPct": round(b, 1)} for a, (v, b) in
                                   sorted(per_app.items(), key=lambda x: -x[1][0])}}, indent=1))
        return
    w = Watcher()
    if "--check" in sys.argv:
        w.check()
        return
    w.check()
    next_tick = time.monotonic()
    while True:
        path = socket_path()
        if not path:
            time.sleep(10)
            continue
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(path)
            buf, due = b"", None
            while True:
                now = time.monotonic()
                if now >= next_tick:
                    w.tick()
                    next_tick = now + TICK
                if due and now >= due:
                    due = None
                    w.check()
                wake = min(next_tick, due) if due else next_tick
                s.settimeout(max(0.1, wake - time.monotonic()))
                try:
                    chunk = s.recv(4096)
                except socket.timeout:
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
