#!/usr/bin/env bash
# omarchy-bar-hide-id removes one id and can put that entry back.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
B=$here/overlay/.local/bin/omarchy-bar-hide-id
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/cfg XDG_STATE_HOME=$tmp/state
mkdir -p "$tmp/cfg/omarchy"
J=$tmp/cfg/omarchy/shell.json
fail=0
ok() { if [[ $(jq -c "$1" "$J") == "$2" ]]; then echo "ok   $3"; else echo "FAIL $3: $(jq -c "$1" "$J")"; fail=1; fi; }
cat >"$J" <<'EOF'
{"bar":{"layout":{"right":[{"id":"omarchy.keyboard-layout"},{"id":"omarchy.agents","refreshIntervalSec":900},{"id":"timon.grok-usage"},{"id":"omarchy.bluetooth"}]}},"disabledPlugins":["omarchy.clipboard"],"plugins":[{"id":"timon.grok-usage"}]}
EOF
"$B" omarchy.agents >/dev/null
ok '[.bar.layout.right[].id]' '["omarchy.keyboard-layout","timon.grok-usage","omarchy.bluetooth"]' "only the robot id leaves the bar"
ok '.disabledPlugins' '["omarchy.clipboard","omarchy.agents"]' "agents disabled, clipboard stays"
ok '.plugins' '[{"id":"timon.grok-usage"}]' "grok usage plugin entry stays"
"$B" omarchy.agents >/dev/null
ok '[.bar.layout.right[].id]' '["omarchy.keyboard-layout","timon.grok-usage","omarchy.bluetooth"]' "second hide changes nothing"
"$B" --undo omarchy.agents >/dev/null
ok '.bar.layout.right[1]' '{"id":"omarchy.agents","refreshIntervalSec":900}' "undo restores the same entry"
ok '.disabledPlugins' '["omarchy.clipboard"]' "undo drops only omarchy.agents"
exit $fail
