#!/bin/bash
# Offscreen render of GlanceVariant.qml (all 4 variants) to PNGs in $1 (default /tmp/glance).
set -u
# Software renderer only (no GPU/RHI: a real RHI init crashed once), no core dumps.
ulimit -c 0
here=$(cd "$(dirname "$0")" && pwd); src="$here/../.."; out=${1:-/tmp/glance}; mkdir -p "$out"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ln -s /usr/share/omarchy/shell/Commons "$tmp/Commons"; ln -s /usr/share/omarchy/shell/Ui "$tmp/Ui"
cp "$src/GlanceVariant.qml" "$here/shell.qml" "$tmp/"; cp -r "$src/assets" "$tmp/"
GLANCE_OUT="$out" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software timeout -k 2 25 quickshell -p "$tmp/shell.qml" 2>&1 | grep -E "GLANCE|ERROR|error" | sed 's/.*GLANCE/GLANCE/'
ls "$out"
