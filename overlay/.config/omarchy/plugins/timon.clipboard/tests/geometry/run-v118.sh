#!/bin/bash
# Offscreen (software) run of the real Clipboard.qml with v118.qml.
# queue.sh and clipboard.sh are replaced by stubs (no key binds, no
# clipboard, no paste); temp data dir, no watchers, hard timeout.
set -u
ulimit -c 0
here=$(cd "$(dirname "$0")" && pwd); src="$here/../.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ln -s /usr/share/omarchy/shell/Commons "$tmp/Commons"; ln -s /usr/share/omarchy/shell/Ui "$tmp/Ui"
mkdir "$tmp/clip" "$tmp/data"; cp "$src"/*.qml "$src"/*.js "$src"/*.sh "$tmp/clip/"; cp "$here/PanelStub.qml" "$tmp/clip/"
printf '#!/bin/bash\n[[ $1 == start ]] && cat > "%s/got"\nexit 0\n' "$tmp" > "$tmp/clip/queue.sh"
printf '#!/bin/bash\necho "$*" >> "%s/helper"\nexit 0\n' "$tmp" > "$tmp/clip/clipboard.sh"; chmod +x "$tmp/clip/"*.sh
printf 'KineticScroll 1.0 KineticScroll.qml\nMarqueeLabel 1.0 MarqueeLabel.qml\nPanelStub 1.0 PanelStub.qml\n' > "$tmp/clip/qmldir"
sed -i -e 's/^  KeyboardPanel {/  PanelStub {/' -e 's/; pkill -f [^"]*"/"/' -e '/textWatchProc.running = true$/d' -e '/imageWatchProc.running = true$/d' -e '/currentProc.running = true$/d' "$tmp/clip/Clipboard.qml"
printf '  function displayModelCount() { return displayModel.count }\n  function displayModelGet(i) { return displayModel.get(i) }\n}\n' > "$tmp/tail"; sed -i '$d' "$tmp/clip/Clipboard.qml"; cat "$tmp/tail" >> "$tmp/clip/Clipboard.qml"
cp "$here/v118.qml" "$tmp/shell.qml"
XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/data" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software setsid timeout -s KILL 20 quickshell -p "$tmp/shell.qml" > "$tmp/out" 2>&1
grep -E 'QUE|ERROR|rror:|TypeError|ReferenceError|Unable' "$tmp/out" | grep -v 'qt.qpa'
echo "QUE helper calls: $(tr "\n" ";" < "$tmp/helper" 2>/dev/null)"
