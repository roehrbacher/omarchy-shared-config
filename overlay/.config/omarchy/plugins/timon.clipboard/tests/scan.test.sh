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
# 1.18.0: real-world QR images (made-up content only).
# url, e-mail and text; a screenshot cropped tight to the code (no quiet
# zone); a light-on-dark code inside a dark screenshot; a small blurred one.
qrencode -o "$d/url.png" -s 6 'https://example.com/menu?table=4'
qrencode -o "$d/mail.png" -s 6 'mailto:someone@example.org'
qrencode -o "$d/text.png" -s 6 'Locker 12, code 0000'
qrencode -o "$d/tight.png" -s 6 -m 0 'https://example.net/tight'
qrencode -t PNG32 -o - -s 6 'WIFI:T:WPA;S:ExampleNet;P:not-a-real-pass;;' | magick - -alpha off -negate -bordercolor '#1e1e2e' -border 120 "$d/dark.png"
qrencode -t PNG32 -o - -s 3 'https://example.org/small' | magick - -alpha off -resize 80% -blur 0x0.6 -bordercolor '#f0f0f0' -border 200 "$d/small.png"
want() { local f=$1 v=$2 out; out=$("$here/../scan.sh" "$d/$f"); [[ $(jq -r .qr <<<"$out") == "$v" ]] && ok "qr $f" || bad "qr $f: got $(jq -r .qr <<<"$out")"; }
want url.png 'https://example.com/menu?table=4'
want mail.png 'mailto:someone@example.org'
want text.png 'Locker 12, code 0000'
want tight.png 'https://example.net/tight'
want dark.png 'WIFI:T:WPA;S:ExampleNet;P:not-a-real-pass;;'
want small.png 'https://example.org/small'
# What 1.16/1.17 (zbar alone, no border) made of the hard ones:
for f in tight dark small; do echo "note zbar-only $f: '$(zbarimg --quiet --raw "$d/$f.png" 2>/dev/null)'"; done
# 1.19.0: OCR languages, with a fake tesseract that has eng, deu, fra installed.
fb="$tmp/fakebin"; mkdir -p "$fb"
printf '#!/bin/bash\n[[ $1 == --list-langs ]] && printf "List of available languages (4):\\neng\\ndeu\\nfra\\nosd\\n"\n' >"$fb/tesseract"; chmod +x "$fb/tesseract"
l() { PATH="$fb:$PATH" "$here/../scan.sh" --langs | jq -r "$1"; }
[[ $(l .used) == "eng+deu+fra" ]] && ok "langs: all installed (eng first)" || bad "langs all: $(l .used)"
[[ $(l '.installed|join(",")') == "deu,eng,fra" ]] && ok "langs: osd not listed" || bad "installed: $(l '.installed|join(",")')"
[[ $(OMARCHY_OCR_LANGS=deu l .used) == deu ]] && ok "langs: OMARCHY_OCR_LANGS=deu" || bad "env deu"
[[ $(OMARCHY_OCR_LANGS=deu+spa l .used) == deu ]] && ok "langs: not-installed spa skipped, nothing downloaded" || bad "env deu+spa"
[[ $(OMARCHY_OCR_LANGS=spa l .used) == "eng+deu+fra" ]] && ok "langs: nothing usable in env -> installed ones" || bad "env spa"
exit $fail
