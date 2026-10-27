#!/bin/bash
# clipboard.sh current (1.20.0): "empty" only when nothing is on the clipboard;
# a password-manager copy and a timeout stay silent (no auto-fill then).
set -u
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/data"; mkdir -p "$tmp/bin" "$tmp/data"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
cat >"$tmp/bin/wl-paste" <<'S'
#!/bin/bash
case "$(cat "$WLMODE")" in
empty) echo "Nothing is copied" >&2; exit 1 ;;
text) [[ $1 == --list-types ]] && printf 'text/plain\nUTF8_STRING\n' || printf 'hello' ;;
secret) [[ $1 == --list-types ]] && printf 'text/plain\nx-kde-passwordManagerHint\n' || printf 'pw' ;;
slow) sleep 5 ;;
esac
S
chmod +x "$tmp/bin/wl-paste"; export PATH="$tmp/bin:$PATH" WLMODE="$tmp/mode"
c() { echo "$1" >"$WLMODE"; "$here/../clipboard.sh" current; }
[[ $(c empty) == empty ]] && ok "nothing copied -> empty" || bad "empty: $(c empty)"
[[ $(c text) == "text:$(printf hello | md5sum | awk '{print $1}')" ]] && ok "text -> its key" || bad "text: $(c text)"
[[ -z $(c secret) ]] && ok "password-manager copy -> nothing (not 'empty')" || bad "secret: $(c secret)"
[[ -z $(c slow) ]] && ok "timeout -> nothing (not 'empty')" || bad "slow: $(c slow)"
exit $fail
