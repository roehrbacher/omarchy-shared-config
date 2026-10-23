#!/bin/bash
# Run: bash tests/markdown.test.sh   (html capture + "Paste as Markdown" conversion, no pandoc)
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/wl-paste" <<'STUB'
#!/bin/bash
[[ ${1:-} == --list-types ]] && { printf '%b' "${FAKE_TYPES:-text/plain\n}"; exit 0; }
[[ ${2:-} == text/html ]] && printf '%s' "${FAKE_HTML:-}"
STUB
chmod +x "$tmp/bin/wl-paste"
# No live window: a real Hyprland session would add its "app" field.
printf "#!/bin/bash\nexit 1\n" >"$tmp/bin/hyprctl"; chmod +x "$tmp/bin/hyprctl"
# Hide a real pandoc so the bundled converter is what is tested.
printf '#!/bin/bash\nexit 127\n' >"$tmp/bin/pandoc"; chmod +x "$tmp/bin/pandoc"
export PATH="$tmp/bin:$PATH" XDG_DATA_HOME="$tmp/data"
fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got '$2' want '$3'"; fail=1; fi; }
H='<meta charset="utf-8"><h2>Plan</h2><p>Read <a href="https://example.org/doc">the doc</a>, <b>then</b> <em>ship</em> <code>v2</code>.</p><ul><li>one</li><li>two<ul><li>nested</li></ul></li></ul><ol><li>first</li><li>second</li></ol><pre><code>make test</code></pre>'
out=$(printf 'Plan Read the doc' | FAKE_TYPES='text/html\ntext/plain\n' FAKE_HTML="$H" "$here/capture.sh" text)
check "html stored with the text" "$(jq -r .html <<<"$out")" "$H"
check "no html temp file left" "$(ls "$tmp/data/timon.clipboard" | grep -c '^html\.')" 0
out2=$(printf 'plain' | FAKE_TYPES='text/html\ntext/plain\n' FAKE_HTML='<span>plain</span>' "$here/capture.sh" text)
check "html without formatting not stored" "$(jq -r '.html // "none"' <<<"$out2")" none
out3=$(printf 'pw' | FAKE_TYPES='text/html\ntext/plain\nx-kde-passwordManagerHint\n' FAKE_HTML="$H" "$here/capture.sh" text)
check "password manager copy: nothing, not even html" "$out3" ""
"$here/clipboard.sh" init
jq -c '[.]' <<<"$out" >"$tmp/data/timon.clipboard/history.json"
want=$(cat <<'MD'
## Plan

Read [the doc](https://example.org/doc), **then** *ship* `v2`.

- one
- two
   - nested

1. first
2. second

```
make test
```
MD
)
check "converted to Markdown (bundled html2md.py)" "$("$here/clipboard.sh" markdown 0)" "$want"
echo '[{"type":"text","text":"just text"}]' >"$tmp/data/timon.clipboard/history.json"
check "no html: falls back to the text" "$("$here/clipboard.sh" markdown 0)" "just text"
# 1.18.0: the pasted Markdown is not captured; the entry is restored after.
D="$tmp/data/timon.clipboard"
printf '%s' '# Hi' | sha256sum | awk '{print $1}' >"$D/skip-next"
check "own Markdown paste not captured" "$(printf '%s' '# Hi' | "$here/capture.sh" text)" ""
check "skip marker used up" "$([[ -e $D/skip-next ]] && echo left || echo gone)" gone
printf '%s' '# Hi' | sha256sum | awk '{print $1}' >"$D/skip-next"
check "a different copy is still captured" "$(printf 'other' | "$here/capture.sh" text | jq -r .text)" other
rm -f "$D/skip-next"
check "same text copied by you later is captured" "$(printf '%s' '# Hi' | "$here/capture.sh" text | jq -r .text)" "# Hi"
# paste-md end to end with a fake clipboard (wl-copy/wl-paste share a file)
cat >"$tmp/bin/wl-copy" <<STUB
#!/bin/bash
cat >"$tmp/board"; echo copy >>"$tmp/log"
STUB
cat >"$tmp/bin/wl-paste" <<STUB
#!/bin/bash
cat "$tmp/board"
STUB
printf '#!/bin/bash\necho paste >>"%s/log"\n' "$tmp" >"$tmp/bin/wtype"
chmod +x "$tmp/bin/"*
jq -c '[.]' <<<"$out" >"$D/history.json"
"$here/clipboard.sh" paste-md 0
check "paste-md: Markdown copied, pasted, then the entry restored" "$(tr '\n' ' ' <"$tmp/log")" "copy paste copy "
check "paste-md: clipboard holds the original text again" "$(cat "$tmp/board")" "Plan Read the doc"
check "paste-md: marker cleaned up" "$([[ -e $D/skip-next ]] && echo left || echo gone)" gone
exit $fail
