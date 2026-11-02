#!/bin/bash
# bash tests/bar-add-once.test.sh   (omarchy-bar-add-once on a fixture shell.json)
set -u
here=$(cd "$(dirname "$0")/.." && pwd); B=$here/overlay/.local/bin/omarchy-bar-add-once
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/cfg XDG_STATE_HOME=$tmp/state; mkdir -p "$tmp/cfg/omarchy"
J=$tmp/cfg/omarchy/shell.json
echo '{"bar":{"layout":{"left":[{"id":"a"}],"right":[{"id":"x"},{"id":"timon.audio"},{"id":"y"}]}}}' >"$J"
fail=0
ok() { if [[ $(jq -c "$1" "$J") == "$2" ]]; then echo "ok   $3"; else echo "FAIL $3: $(jq -c "$1" "$J")"; fail=1; fi; }
"$B" timon.mic-passthrough timon.audio omarchy.audio >/dev/null
ok '[.bar.layout.right[].id]' '["x","timon.audio","timon.mic-passthrough","y"]' "inserted right after timon.audio"
ok '[.bar.layout.left[].id]' '["a"]' "other sections untouched"
"$B" timon.mic-passthrough timon.audio >/dev/null
ok '[.bar.layout.right[].id]|length' '4' "second run adds nothing"
jq '.bar.layout.right |= map(select(.id != "timon.mic-passthrough"))' "$J" >"$J.n" && mv "$J.n" "$J"
"$B" timon.mic-passthrough timon.audio >/dev/null
ok '[.bar.layout.right[].id]' '["x","timon.audio","y"]' "removed by hand stays removed"
rm -rf "$tmp/state"; echo '{"bar":{"layout":{"right":[{"id":"omarchy.audio"},{"id":"z"}]}}}' >"$J"
"$B" timon.mic-passthrough timon.audio omarchy.audio >/dev/null
ok '[.bar.layout.right[].id]' '["omarchy.audio","timon.mic-passthrough","z"]' "falls back to omarchy.audio"
rm -rf "$tmp/state"; echo '{"bar":{"layout":{"right":[{"id":"z"}]}}}' >"$J"
"$B" w nope >/dev/null
ok '[.bar.layout.right[].id]' '["z","w"]' "no neighbour: end of right"
rm -f "$J"; rm -rf "$tmp/state"; "$B" w nope && [[ ! -e $J ]] && echo "ok   missing shell.json: no-op" || { echo "FAIL missing shell.json"; fail=1; }
exit $fail
