#!/bin/bash
# Software renderer, offscreen, no core dumps; compiles BarWidget.qml only.
set -u; ulimit -c 0
here=$(cd "$(dirname "$0")" && pwd); src="$here/../.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ln -s /usr/share/omarchy/shell/Commons "$tmp/Commons"; ln -s /usr/share/omarchy/shell/Ui "$tmp/Ui"
cp "$src"/*.qml "$here/load.qml" "$tmp/"; cp -r "$src/assets" "$src/lib" "$src/scripts" "$tmp/"; mv "$tmp/load.qml" "$tmp/shell.qml"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software timeout -k 2 15 quickshell -p "$tmp/shell.qml" 2>&1 | grep -E "LOAD" | sed 's/.*LOAD/LOAD/'
