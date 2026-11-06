#!/usr/bin/env bash
# omarchy-bar-replace-id keeps every other bar entry and does not disable the old plugin.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
B=$here/overlay/.local/bin/omarchy-bar-replace-id
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/cfg
mkdir -p "$tmp/cfg/omarchy"
J=$tmp/cfg/omarchy/shell.json
fail=0
ok() { if [[ $(jq -c "$1" "$J") == "$2" ]]; then echo "ok   $3"; else echo "FAIL $3: $(jq -c "$1" "$J")"; fail=1; fi; }
cat >"$J" <<'EOF'
{"bar":{"layout":{"left":[{"id":"omarchy.menu","showLabel":false},{"id":"omarchy.workspaces"}],"right":[{"id":"timon.grok-usage"}]}},"disabledPlugins":["omarchy.clipboard"]}
EOF
"$B" omarchy.menu timon.omacast-logo >/dev/null
ok '.bar.layout.left' '[{"id":"timon.omacast-logo","showLabel":false},{"id":"omarchy.workspaces"}]' "logo swapped in place"
ok '.bar.layout.right' '[{"id":"timon.grok-usage"}]' "other section untouched"
ok '.disabledPlugins' '["omarchy.clipboard"]' "old menu plugin stays enabled"
"$B" omarchy.menu timon.omacast-logo >/dev/null
ok '.bar.layout.left[0].id' '"timon.omacast-logo"' "second run is a no-op"
"$B" timon.omacast-logo omarchy.menu >/dev/null
ok '.bar.layout.left[0].id' '"omarchy.menu"' "undo swaps the id back"
rm -f "$J"
"$B" omarchy.menu timon.omacast-logo && [[ ! -e $J ]] && echo "ok   missing shell.json" || { echo "FAIL missing shell.json"; fail=1; }
exit $fail
