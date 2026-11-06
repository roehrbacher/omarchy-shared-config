#!/usr/bin/env bash
# Logo uses one global IPC. Reload icon has no poll timer.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
logo=$here/overlay/.config/omarchy/plugins/timon.omacast-logo/BarWidget.qml
reload=$here/overlay/.config/omarchy/plugins/timon.reload-needed/ReloadNeeded.qml
mark=$here/overlay/.local/bin/omarchy-mark-reload-needed
shell=$here/overlay/.config/omarchy/shell.d/00-shared.json
fail=0
need() { if grep -qF "$1" "$2"; then echo "ok   $3"; else echo "FAIL $3"; fail=1; fi; }
forbid() { if grep -qF "$1" "$2"; then echo "FAIL $3"; fail=1; else echo "ok   $3"; fi; }
need 'hyprctl dispatch global omacast:toggle' "$logo" "logo dispatches omacast:toggle"
need 'xdg-terminal-exec' "$logo" "right click still opens a terminal"
forbid 'omarchy-shell' "$logo" "logo does not also call shell IPC"
forbid 'toggle omarchy.menu' "$logo" "logo does not open the stock menu"
forbid 'Timer' "$reload" "reload icon has no timer"
need 'FileView' "$reload" "reload icon watches the flag file"
need 'flagPath' "$reload" "reload icon uses the flag path"
forbid 'sleep' "$mark" "reload helper does not sleep"
need 'omarchy-shell -q timon.reload-needed refresh' "$mark" "helper refreshes over shell IPC"
# The icon click restarts immediately. It does not call the idle gate.
click=$(sed -n '/function reloadShell()/,/^  }/p' "$reload")
printf '%s\n' "$click" | grep -q 'exec omarchy restart shell' && echo "ok   click runs the shell restart" || { echo "FAIL click command"; fail=1; }
if printf '%s\n' "$click" | grep -Eq 'safe-gate|idle|sleep |qs '; then
  echo "FAIL click waits or calls the idle gate" >&2
  fail=1
else
  echo "ok   click does not wait for idle"
fi
if grep -q 'omarchy restart shell' "$mark"; then echo "FAIL helper restarts the shell"; fail=1; else echo "ok   helper does not restart the shell"; fi
python3 - "$shell" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
fail = 0
disabled = doc.get("disabledPlugins") or []
print("ok   omarchy.agents disabled" if "omarchy.agents" in disabled else "FAIL omarchy.agents not disabled")
print("ok   grok usage not disabled" if "timon.grok-usage" not in disabled else "FAIL grok usage disabled")
if "omarchy.agents" not in disabled or "timon.grok-usage" in disabled:
    fail = 1
sys.exit(fail)
PY
fail=$((fail + $?))
exit $fail
