#!/bin/bash
# timon.clipboard: reads text (tesseract OCR) and QR codes (zbarimg) from one
# stored clipboard image and prints {"ocr","qr","complete"} as JSON on stdout.
# Runs niced in the background; the text is never logged or put in argv.
#   scan.sh <image-path>          (only files inside the plugin's image dir)
set -uo pipefail
umask 077
IMAGE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/timon.clipboard/images"

# OCR languages (1.19.0): only language packs that are installed are used;
# nothing is ever downloaded. Like Omarchy's own omarchy-capture-text,
# OMARCHY_OCR_LANGS (e.g. "eng+deu") picks them; without it every installed
# pack is used (English first, at most 3, so a scan stays quick).
#   scan.sh --langs     print {"installed":[...],"used":"eng+deu","env":"..."}
ocr_installed() { tesseract --list-langs 2>/dev/null | tail -n +2 | grep -vxE 'osd|equ|snum' | sort -u; }
ocr_langs() {
  local have want picked=()
  have=$(ocr_installed)
  [[ -n $have ]] || return 0
  if [[ -n ${OMARCHY_OCR_LANGS:-} ]]; then
    for want in ${OMARCHY_OCR_LANGS//+/ }; do grep -qx "$want" <<<"$have" && picked+=("$want"); done
  fi
  if (( ${#picked[@]} == 0 )); then
    grep -qx eng <<<"$have" && picked+=(eng)
    while read -r want; do [[ $want == eng ]] || picked+=("$want"); done <<<"$have"
    picked=("${picked[@]:0:3}")
  fi
  local IFS=+; echo "${picked[*]}"
}
if [[ ${1:-} == --langs ]]; then
  command -v tesseract >/dev/null || { echo '{"installed":[],"used":"","env":""}'; exit 0; }
  jq -cn --arg inst "$(ocr_installed)" --arg used "$(ocr_langs)" --arg env "${OMARCHY_OCR_LANGS:-}" \
    '{installed: ($inst | split("\n") | map(select(. != ""))), used: $used, env: $env}'
  exit 0
fi
img=${1:-}
[[ $img == "$IMAGE_DIR"/* && -r $img ]] || exit 1

# QR codes (1.18.0): zbar (in Omarchy's base packages) misses many real
# codes: styled/rounded modules, screenshots cropped without the white quiet
# zone, light-on-dark codes. ZXing (zxing-cpp's ZXingReader, present on
# Omarchy via LibreOffice / GStreamer) reads those, also inverted ones, so
# it goes first; zbar is the fallback, retried with a white border added
# (ImageMagick) for tightly cropped codes.
complete=true ocr="" qr=""
if command -v ZXingReader >/dev/null; then
  qr=$(timeout 15s nice -n 19 ZXingReader -single -formats QRCode -bytes "$img" 2>/dev/null | head -c 4096)
fi
if [[ -z $qr ]] && command -v zbarimg >/dev/null; then
  qr=$(timeout 15s nice -n 19 zbarimg --quiet --raw -- "$img" 2>/dev/null | head -c 4096)
  if [[ -z $qr ]] && command -v magick >/dev/null; then
    qr=$(timeout 15s nice -n 19 magick "$img" -bordercolor white -border 10% png:- 2>/dev/null | timeout 15s nice -n 19 zbarimg --quiet --raw - 2>/dev/null | head -c 4096)
  fi
elif ! command -v ZXingReader >/dev/null; then
  complete=false
fi
if command -v tesseract >/dev/null; then
  langs=$(ocr_langs); [[ -n $langs ]] || langs=eng
  ocr=$(OMP_THREAD_LIMIT=1 timeout 30s nice -n 19 tesseract "$img" - -l "$langs" 2>/dev/null | head -c 8192)
else
  complete=false
fi
jq -cn --arg ocr "$ocr" --arg qr "$qr" --argjson complete "$complete" '{ocr: ($ocr | gsub("^\\s+|\\s+$"; "")), qr: ($qr | gsub("^\\s+|\\s+$"; "")), complete: $complete}'
