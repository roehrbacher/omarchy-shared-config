#!/bin/bash
# Offscreen geometry check of the real Clipboard.qml (KeyboardPanel replaced
# by PanelStub, no layer surface): prints header/row/button positions.
# Uses a temporary data dir; nothing touches the real history.
set -u
here=$(cd "$(dirname "$0")" && pwd); src="$here/../.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ln -s /usr/share/omarchy/shell/Commons "$tmp/Commons"; ln -s /usr/share/omarchy/shell/Ui "$tmp/Ui"
mkdir "$tmp/clip" "$tmp/data"; cp "$src"/*.qml "$src"/*.js "$src"/*.sh "$tmp/clip/" 2>/dev/null; cp "$here/PanelStub.qml" "$tmp/clip/"
printf 'KineticScroll 1.0 KineticScroll.qml\nMarqueeLabel 1.0 MarqueeLabel.qml\nPanelStub 1.0 PanelStub.qml\n' > "$tmp/clip/qmldir"
sed -i 's/^  KeyboardPanel {/  PanelStub {/' "$tmp/clip/Clipboard.qml"
cp "$here/shell.qml" "$tmp/"
XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/data" QT_QPA_PLATFORM=offscreen setsid quickshell -p "$tmp/shell.qml" > "$tmp/out" 2>&1 &
pid=$!; sleep 15; pg=$(ps -o pgid= "$pid" | tr -d ' '); [ -n "$pg" ] && kill -KILL -- "-$pg" 2>/dev/null
grep -o 'GEO.*' "$tmp/out"
