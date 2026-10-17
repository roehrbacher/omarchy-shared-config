#!/bin/bash
# Run: bash tests/capture.test.sh   (needs jq, perl; wl-paste is stubbed)
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/wl-paste" <<'STUB'
#!/bin/bash
[[ ${1:-} == --list-types ]] && printf '%b' "${FAKE_TYPES:-text/plain\n}"
STUB
chmod +x "$tmp/bin/wl-paste"
export PATH="$tmp/bin:$PATH" XDG_DATA_HOME="$tmp/data"
fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got '$2' want '$3'"; fail=1; fi; }

out=$(printf 'hello world' | "$here/capture.sh" text)
check "text captured" "$out" '{"type":"text","text":"hello world"}'
check "data dir is 0700" "$(stat -c %a "$tmp/data/timon.clipboard")" 700

out=$(printf 'hunter2' | FAKE_TYPES='text/plain\nx-kde-passwordManagerHint\n' "$here/capture.sh" text)
check "password manager copy skipped" "$out" ""

out=$(printf 'secret' | CLIPBOARD_STATE=sensitive "$here/capture.sh" text)
check "sensitive clipboard state skipped" "$out" ""

echo '{"private": true}' >"$tmp/data/timon.clipboard/state.json"
out=$(printf 'private stuff' | "$here/capture.sh" text)
check "private mode skips text" "$out" ""
out=$(printf '\x89PNG\r\n\x1a\nfake' | "$here/capture.sh" image/png)
check "private mode skips images" "$out" ""
check "no image written in private mode" "$(ls "$tmp/data/timon.clipboard/images" | wc -l)" 0
echo '{"private": false}' >"$tmp/data/timon.clipboard/state.json"

out=$(printf '\x89PNG\r\n\x1a\nfake' | "$here/capture.sh" image/png | jq -r .type)
check "image captured" "$out" image
img=$(ls "$tmp/data/timon.clipboard/images")
check "image file is 0600" "$(stat -c %a "$tmp/data/timon.clipboard/images/$img")" 600

out=$(head -c $((5 * 1024 * 1024)) /dev/zero | tr '\0' a | "$here/capture.sh" text)
check "huge text (>4 MiB) skipped" "$out" ""

# helper: init imports stock history once, prune drops orphans
mkdir -p "$tmp/state/omarchy"
echo '[{"type":"text","text":"from stock"}]' >"$tmp/state/omarchy/clipboard-history.json"
rm -rf "$tmp/data/timon.clipboard"
XDG_STATE_HOME="$tmp/state" "$here/clipboard.sh" init
check "stock history imported" "$(jq -r '.[0].text' "$tmp/data/timon.clipboard/history.json")" "from stock"
check "history file is 0600" "$(stat -c %a "$tmp/data/timon.clipboard/history.json")" 600
touch "$tmp/data/timon.clipboard/images/orphan.png"
"$here/clipboard.sh" prune
check "prune removes orphan images" "$(ls "$tmp/data/timon.clipboard/images" | wc -l)" 0

exit $fail
