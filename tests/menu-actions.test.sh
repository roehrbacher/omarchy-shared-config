#!/usr/bin/env bash
# Power Off command and Insomnia popup, with the power command mocked.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
export HOME=$tmp/home OMARCHY_PATH=$tmp/omarchy
mkdir -p "$HOME/.config/omarchy/menu.d" \
  "$HOME/Work/omarchy-insomnia" "$HOME/Work/notes" \
  "$OMARCHY_PATH/default/omarchy" "$tmp/bin"
cp "$here/overlay/.config/omarchy/menu.d/00-shared.jsonc" "$HOME/.config/omarchy/menu.d/00-shared.jsonc"
cat >"$OMARCHY_PATH/default/omarchy/omarchy-menu.jsonc" <<'EOF'
{
  "system.shutdown": {"icon":"x","label":"Shutdown","action":"omarchy-system shutdown","aliases":["shutdown"]},
  "apps": {"icon":"a","label":"Apps","aliases":["applications"]}
}
EOF
built=$("$here/overlay/.local/bin/omarchy-menu-build" --dry-run) || { echo "FAIL menu-build"; exit 1; }
python3 - "$built" <<'PY'
import json, re, sys
raw = re.sub(r"^\s*//[^\n]*(\n|$)", "", sys.argv[1], flags=re.M)
raw = re.sub(r",(\s*[}\]])", r"\1", raw)
doc = json.loads(raw)
fail = 0
def check(cond, msg):
    global fail
    print(("ok  " if cond else "FAIL ") + msg)
    if not cond: fail = 1
power = doc.get("system.poweroff") or {}
check(power.get("label") == "Power Off", "Power Off label")
check(power.get("action") == "omarchy-system shutdown", "spaced shutdown command")
check("omarchy-system-shutdown" not in json.dumps(doc), "hyphenated binary is absent")
check(doc.get("system.shutdown", {}).get("when") == "false", "stock Shutdown row hidden")
ins = doc.get("insomnia") or {}
check(ins.get("action") == "omarchy-insomnia menu", "Insomnia opens the picker")
check("set" not in ins.get("action", ""), "Insomnia action is not set")
check(all("omarchy-insomnia" not in (row.get("action") or "") or row.get("action") == "omarchy-insomnia menu"
          for row in doc.values()), "no folder action for the insomnia checkout")
check(any(row.get("label") == "notes" and "nautilus" in row.get("action", "") for row in doc.values()),
      "a real Work folder is still listed")
sys.exit(fail)
PY
fail=$?
cat >"$tmp/bin/omarchy-system" <<'EOF'
#!/bin/bash
echo "MOCK $*"
if [[ "$*" == *poweroff* || "$*" == *reboot* || "$*" == *systemctl* ]]; then
  echo "refused real power action" >&2
  exit 9
fi
EOF
chmod +x "$tmp/bin/omarchy-system"
action=$(python3 -c 'import json,re,sys; raw=re.sub(r"^\s*//[^\n]*(\n|$)","",sys.stdin.read(),flags=re.M); raw=re.sub(r",(\s*[}\]])",r"\1",raw); print(json.loads(raw)["system.poweroff"]["action"])' <<<"$built")
if [[ $action != "omarchy-system shutdown" ]]; then
  echo "FAIL refusing to run unexpected action: $action"; exit 1
fi
out=$(PATH="$tmp/bin:$PATH" omarchy-system shutdown)
[[ $out == "MOCK shutdown" ]] && echo "ok   mock ran the spaced command" || { echo "FAIL mock output: $out"; fail=1; }
[[ ! -x $tmp/bin/omarchy-system-shutdown ]] && echo "ok   hyphenated command is not provided" || { echo "FAIL hyphenated mock"; fail=1; }
desk=$here/overlay/.local/share/applications/omarchy-insomnia.desktop
grep -qx 'Exec=omarchy-insomnia menu' "$desk" && echo "ok   desktop opens the picker" || { echo "FAIL desktop exec"; fail=1; }
[[ $(basename "$desk") != insomnia.desktop ]] && echo "ok   desktop id is not the REST client" || { echo "FAIL desktop name"; fail=1; }
grep -q 'Name=Insomnia' "$desk" && echo "ok   desktop label Insomnia" || { echo "FAIL desktop label"; fail=1; }
! grep -q 'omarchy-insomnia set' "$desk" && echo "ok   desktop does not set inhibitor state" || { echo "FAIL desktop set"; fail=1; }
exit $fail
