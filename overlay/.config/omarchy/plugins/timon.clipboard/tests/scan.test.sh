#!/bin/bash
# scan.sh on generated images: OCR text, QR content, refuses paths outside the image dir.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_DATA_HOME="$tmp"; d="$tmp/timon.clipboard/images"; mkdir -p "$d"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
command -v magick >/dev/null && command -v qrencode >/dev/null || { echo "skip: needs magick + qrencode"; exit 0; }
magick -size 900x200 xc:white -fill black -pointsize 64 -annotate +30+120 'Invoice 4711' "$d/a.png"
qrencode -o "$d/q.png" -s 8 'WIFI:T:WPA;S:Test;P:hunter2;;'
out=$("$here/../scan.sh" "$d/a.png"); jq -e '.ocr | test("Invoice 4711")' <<<"$out" >/dev/null && ok "ocr text" || bad "ocr text: $out"
out=$("$here/../scan.sh" "$d/q.png"); jq -e '.qr == "WIFI:T:WPA;S:Test;P:hunter2;;"' <<<"$out" >/dev/null && ok "qr text" || bad "qr: $out"
jq -e '.complete == true' <<<"$out" >/dev/null && ok "complete with both tools" || echo "note: a tool is missing ($out)"
cp "$d/a.png" "$tmp/x.png"; "$here/../scan.sh" "$tmp/x.png" >/dev/null 2>&1 && bad "outside image dir accepted" || ok "outside image dir refused"
exit $fail
