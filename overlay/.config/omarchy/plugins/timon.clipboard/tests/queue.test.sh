#!/bin/bash
# Run: bash tests/queue.test.sh   (paste queue; hyprctl, wl-copy and notify are stubbed)
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf '#!/bin/bash\ncat > "%s/clip"; echo "$*" >> "%s/copies"\n' "$tmp" "$tmp" >"$tmp/bin/wl-copy"
chmod +x "$tmp/bin/wl-copy"
export PATH="$tmp/bin:$PATH" XDG_DATA_HOME="$tmp/data" QUEUE_DRY=1
Q="$tmp/data/timon.clipboard/queue.json"
fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got '$2' want '$3'"; fail=1; fi; }

out=$(printf '%s' '[{"type":"text","text":"one"},{"type":"text","text":"two"},{"type":"text","text":"three"}]' | "$here/queue.sh" start)
check "start binds Ctrl+V" "$(grep -c 'hl.bind("CTRL + V"' <<<"$out")" 1
check "start binds Super+V to next (1.22.0)" "$(grep -c 'hl.bind("SUPER + V", hl.dsp.exec_cmd("setsid -f .*queue.sh next")' <<<"$out")" 1
check "start swaps out the stock Super+V first" "$(grep -nE 'unbind\("SUPER \+ V"\)|bind\("SUPER \+ V", hl.dsp' <<<"$out" | head -1 | grep -c unbind)" 1
check "start binds Esc" "$(grep -c 'hl.bind("Escape"' <<<"$out")" 1
check "start notification (1.21.0 text)" "$(grep '^notify' <<<"$out")" "notify Paste queue ready:|Paste 1 of 3. Esc cancels."
check "queue file is 0600" "$(stat -c %a "$Q")" 600
check "status" "$("$here/queue.sh" status)" '{"pos":0,"count":3}'
out=$("$here/queue.sh" next)
check "1st Ctrl+V copies item 1" "$(cat "$tmp/clip")" one
check "1st Ctrl+V sends Shift+Insert" "$(grep -c 'mods = "SHIFT", key = "Insert"' <<<"$out")" 2
check "Paste 1 of 3 notification" "$(grep -o 'Pasted 1 of 3' <<<"$out")" "Pasted 1 of 3"
"$here/queue.sh" next >/dev/null
check "2nd Ctrl+V copies item 2" "$(cat "$tmp/clip")" two
out=$("$here/queue.sh" next)
check "3rd Ctrl+V copies item 3" "$(cat "$tmp/clip")" three
check "after the last: done" "$(grep -o 'Pasted 3 of 3. Done.' <<<"$out")" "Pasted 3 of 3. Done."
check "after the last: unbinds" "$(grep -c 'hl.unbind' <<<"$out")" 3
check "after the last: universal paste back on Super+V" "$(grep -c 'hl.bind("SUPER + V", function() .*send_key_state.*"Universal paste"' <<<"$out")" 1
check "after the last: queue file gone" "$([[ -e $Q ]] && echo yes || echo no)" no
check "status empty" "$("$here/queue.sh" status)" ""
out=$("$here/queue.sh" next)
check "Ctrl+V with no queue only unbinds (no key sent)" "$(grep -c '^hyprctl dispatch' <<<"$out")" 0

printf '%s' '[{"type":"text","text":"a"},{"type":"text","text":"b"}]' | "$here/queue.sh" start >/dev/null
"$here/queue.sh" next >/dev/null
out=$("$here/queue.sh" cancel esc)
check "Esc cancels" "$(grep -o 'Cancelled after 1 of 2' <<<"$out")" "Cancelled after 1 of 2"
check "Esc unbinds before passing Esc on" "$(grep -nE 'unbind|Escape", state' <<<"$out" | head -1 | grep -c unbind)" 1
check "Esc is passed on to the window" "$(grep -c 'key = "Escape", state' <<<"$out")" 2
check "cancel: queue file gone" "$([[ -e $Q ]] && echo yes || echo no)" no

# 1.21.0: a new pick in the popup drops the queue silently.
printf '%s' '[{"type":"text","text":"a"},{"type":"text","text":"b"}]' | "$here/queue.sh" start >/dev/null
out=$("$here/queue.sh" cancel quiet)
check "quiet cancel: no notification" "$(grep -c '^notify' <<<"$out")" 0
check "quiet cancel: unbinds Ctrl+V, Super+V and Esc" "$(grep -c 'hl.unbind' <<<"$out")" 3
check "quiet cancel: universal paste restored" "$(grep -c '"Universal paste"' <<<"$out")" 1
check "quiet cancel: Esc not sent on" "$(grep -c 'key = "Escape", state' <<<"$out")" 0
check "quiet cancel: queue file gone" "$([[ -e $Q ]] && echo yes || echo no)" no

out=$(printf '%s' '[{"type":"bogus"},{"type":"text","text":""}]' | "$here/queue.sh" start; echo "rc=$?")
check "nothing valid: not armed" "$(grep -c 'hl.bind' <<<"$out")" 0
mkdir -p "$tmp/data/timon.clipboard/images"; printf 'PNG' >"$tmp/data/timon.clipboard/images/x.png"
printf '%s' "[{\"type\":\"image\",\"path\":\"$tmp/data/timon.clipboard/images/x.png\",\"mime\":\"image/png\"},{\"type\":\"image\",\"path\":\"/etc/passwd\"}]" | "$here/queue.sh" start >/dev/null
"$here/queue.sh" next >/dev/null
check "image item copied with its type" "$(tail -1 "$tmp/copies")" "--type image/png"
: >"$tmp/clip"; "$here/queue.sh" next >/dev/null
check "image outside the image dir refused" "$(cat "$tmp/clip")" ""
# 1.18.0 regression: real wl-copy forks a daemon that keeps serving the
# clipboard. In 1.17.0 it inherited the queue lock, so the 2nd Ctrl+V found
# the lock taken and pasted nothing. This stub forks the same way.
printf '#!/bin/bash\ncat > "%s/clip"\n( exec sleep 20 ) &\n' "$tmp" >"$tmp/bin/wl-copy"
printf '%s' '[{"type":"text","text":"first"},{"type":"text","text":"second"},{"type":"text","text":"third"}]' | "$here/queue.sh" start >/dev/null
"$here/queue.sh" next >/dev/null
check "daemonising wl-copy: item 1" "$(cat "$tmp/clip")" first
s0=$(date +%s); "$here/queue.sh" next >/dev/null; rc=$?
check "daemonising wl-copy: 2nd Ctrl+V runs" "$rc" 0
check "daemonising wl-copy: item 2 pasted" "$(cat "$tmp/clip")" second
check "daemonising wl-copy: no lock wait" "$(( $(date +%s) - s0 < 2 ))" 1
"$here/queue.sh" next >/dev/null
check "daemonising wl-copy: item 3 pasted" "$(cat "$tmp/clip")" third
pkill -f 'sleep 20' 2>/dev/null
exit $fail
