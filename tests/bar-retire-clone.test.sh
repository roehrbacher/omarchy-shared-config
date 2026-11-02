#!/bin/bash
# bash tests/bar-retire-clone.test.sh   (omarchy-bar-retire-clone on a fixture shell.json)
set -u
here=$(cd "$(dirname "$0")/.." && pwd); B=$here/overlay/.local/bin/omarchy-bar-retire-clone
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/cfg; mkdir -p "$tmp/cfg/omarchy"; J=$tmp/cfg/omarchy/shell.json
echo '{"bar":{"layout":{"right":[{"id":"a"},{"id":"timon.network","x":1},{"id":"b"}]}},"plugins":[{"id":"timon.network"},{"id":"k"}],"disabledPlugins":["omarchy.network","omarchy.lock"],"cloneSourceRestores":["timon.network","timon.lock"]}' >"$J"
fail=0
ok() { if [[ $(jq -c "$1" "$J") == "$2" ]]; then echo "ok   $3"; else echo "FAIL $3: $(jq -c "$1" "$J")"; fail=1; fi; }
"$B" timon.network omarchy.network >/dev/null
ok '.bar.layout.right' '[{"id":"a"},{"id":"omarchy.network","x":1},{"id":"b"}]' "swapped in place, settings kept"
ok '[.plugins[].id]' '["k"]' "clone dropped from plugins"
ok '.disabledPlugins' '["omarchy.lock"]' "stock re-enabled"
ok '.cloneSourceRestores' '["timon.lock"]' "clone restore dropped"
cp "$J" "$tmp/before"; "$B" timon.network omarchy.network >/dev/null
cmp -s "$J" "$tmp/before" && echo "ok   second run changes nothing" || { echo "FAIL second run"; fail=1; }
echo '{"bar":{"layout":{"right":[{"id":"omarchy.network"},{"id":"timon.network"}]}}}' >"$J"
"$B" timon.network omarchy.network >/dev/null
ok '.bar.layout.right' '[{"id":"omarchy.network"}]' "no duplicate when stock already there"
exit $fail
