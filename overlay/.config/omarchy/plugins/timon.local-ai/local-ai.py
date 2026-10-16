#!/usr/bin/env python3
"""Helper for the timon.local-ai bar plugin.

  local-ai.py state          print models + live state as JSON
  local-ai.py start UNIT     start a model (stops the others when "exclusive")
  local-ai.py stop UNIT      stop a model

Models come from ~/.config/omarchy/local-ai.json plus, when "autoDiscover" is
on, every llama-*.service user unit not listed there. Units are only ever
started/stopped, never enabled or disabled.

With "listFiles" on (default), .gguf files in "modelDirs" that no model unit
points at are listed too ("files" in the state JSON), so a freshly downloaded
model shows up as downloaded but not set up to run. Nothing is ever started
for them.
"""
import json, os, re, subprocess, sys, urllib.request

CONFIG = os.path.expanduser("~/.config/omarchy/local-ai.json")
DEFAULTS = {"exclusive": True, "autoDiscover": True, "discoverPattern": "llama-*.service", "models": [],
            "listFiles": True,
            "modelDirs": ["~/Models", "~/models", "~/.cache/llama.cpp", "~/.cache/huggingface/hub",
                          "~/.lmstudio/models"]}
SPLIT_PART = re.compile(r"-(\d{5})-of-\d{5}$")


def run(*args, timeout=5):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except Exception as exc:  # noqa: BLE001
        return subprocess.CompletedProcess(args, 1, "", str(exc))


def load_config():
    cfg = dict(DEFAULTS)
    error = ""
    try:
        with open(CONFIG) as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            cfg.update(data)
    except FileNotFoundError:
        pass
    except Exception as exc:  # noqa: BLE001
        error = f"local-ai.json: {exc}"
    return cfg, error


def unit_name(unit):
    unit = str(unit or "").strip()
    return unit if not unit or "." in unit else unit + ".service"


def discover(pattern):
    out = run("systemctl", "--user", "list-unit-files", "--type=service", "--no-legend", "--plain", pattern)
    units = []
    for line in out.stdout.splitlines():
        parts = line.split()
        if parts and not parts[0].endswith("@.service"):
            units.append(parts[0])
    return units


def nice_name(unit, description):
    match = re.search(r"\(([^)]+)\)\s*$", description or "")
    if match:
        return match.group(1)
    if description:
        return description
    return re.sub(r"\.service$", "", unit)


def show(units):
    if not units:
        return {}
    out = run("systemctl", "--user", "show", "--property=Id,Description,ActiveState,SubState,LoadState,ExecStart", *units)
    info, cur = {}, {}
    for line in out.stdout.splitlines() + [""]:
        if not line.strip():
            if cur.get("Id"):
                info[cur["Id"]] = cur
            cur = {}
            continue
        key, _, value = line.partition("=")
        cur[key] = value
    return info


def healthy(url):
    if not url:
        return None
    try:
        with urllib.request.urlopen(url, timeout=0.6) as resp:
            return 200 <= resp.status < 300
    except Exception:  # noqa: BLE001
        return False


def gguf_files(dirs, used):
    """.gguf model files under dirs that no unit's ExecStart mentions."""
    found, seen = [], set()
    for d in dirs or []:
        root = os.path.expanduser(str(d))
        if not os.path.isdir(root):
            continue
        base = root.count(os.sep)
        for cur, subdirs, names in os.walk(root, followlinks=False):
            if cur.count(os.sep) - base >= 5:
                subdirs[:] = []
            subdirs[:] = [x for x in subdirs if not x.startswith(".")]
            for n in names:
                stem, ext = os.path.splitext(n)
                if ext.lower() != ".gguf" or n.lower().startswith("mmproj"):
                    continue
                part = SPLIT_PART.search(stem)
                if part and part.group(1) != "00001":
                    continue
                path = os.path.join(cur, n)
                real = os.path.realpath(path)
                if real in seen or not os.path.isfile(real):
                    continue
                seen.add(real)
                if path in used or real in used or n in used:
                    continue
                name = SPLIT_PART.sub("", stem)
                try:
                    size = os.path.getsize(real)
                except OSError:
                    size = 0
                found.append({"name": name, "path": path, "sizeGB": round(size / 1e9, 1),
                              "mtime": int(os.path.getmtime(real))})
    found.sort(key=lambda f: -f["mtime"])
    return found


def used_paths(info):
    used = set()
    for i in info.values():
        for tok in re.split(r"[\s;=]+", i.get("ExecStart", "")):
            if tok.lower().endswith(".gguf"):
                used.update({tok, os.path.realpath(tok), os.path.basename(tok)})
    return used


def models(cfg):
    listed = []
    seen = set()
    for entry in cfg.get("models") or []:
        if not isinstance(entry, dict):
            continue
        unit = unit_name(entry.get("unit"))
        if not unit or unit in seen:
            continue
        seen.add(unit)
        listed.append({"unit": unit, "name": entry.get("name") or "", "healthUrl": entry.get("healthUrl") or "",
                       "detail": entry.get("detail") or ""})
    if cfg.get("autoDiscover", True):
        for unit in discover(cfg.get("discoverPattern") or DEFAULTS["discoverPattern"]):
            if unit not in seen:
                seen.add(unit)
                listed.append({"unit": unit, "name": "", "healthUrl": "", "detail": "", "discovered": True})
    return listed


def state():
    cfg, error = load_config()
    items = models(cfg)
    info = show([m["unit"] for m in items])
    out = []
    for m in items:
        i = info.get(m["unit"], {})
        if i.get("LoadState") == "not-found":
            continue
        active = i.get("ActiveState", "inactive")
        ok = healthy(m["healthUrl"]) if active == "active" else None
        if active == "active":
            st = "on" if ok in (None, True) else "loading"
        elif active in ("activating", "reloading"):
            st = "loading"
        elif active == "deactivating":
            st = "stopping"
        elif active == "failed":
            st = "failed"
        else:
            st = "off"
        out.append({"unit": m["unit"], "name": m["name"] or nice_name(m["unit"], i.get("Description", "")),
                    "detail": m["detail"], "activeState": active, "subState": i.get("SubState", ""),
                    "state": st, "healthy": ok, "discovered": bool(m.get("discovered"))})
    files = gguf_files(cfg.get("modelDirs"), used_paths(info)) if cfg.get("listFiles", True) else []
    print(json.dumps({"exclusive": bool(cfg.get("exclusive", True)), "models": out, "files": files,
                      "error": error, "config": CONFIG}))


def start(unit):
    cfg, _ = load_config()
    unit = unit_name(unit)
    if cfg.get("exclusive", True):
        others = [m["unit"] for m in models(cfg) if m["unit"] != unit]
        info = show(others)
        running = [u for u in others if info.get(u, {}).get("ActiveState") in ("active", "activating", "reloading")]
        if running:
            run("systemctl", "--user", "stop", *running, timeout=60)
    run("systemctl", "--user", "reset-failed", unit)
    res = run("systemctl", "--user", "start", "--no-block", unit)
    sys.exit(res.returncode)


def stop(unit):
    res = run("systemctl", "--user", "stop", "--no-block", unit_name(unit))
    sys.exit(res.returncode)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "state"
    if cmd == "state":
        state()
    elif cmd in ("start", "stop") and len(sys.argv) == 3:
        (start if cmd == "start" else stop)(sys.argv[2])
    else:
        sys.exit("usage: local-ai.py state | start UNIT | stop UNIT")
