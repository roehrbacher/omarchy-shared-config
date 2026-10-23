#!/bin/bash
# timon.clipboard: reads text (tesseract OCR) and QR codes (zbarimg) from one
# stored clipboard image and prints {"ocr","qr","complete"} as JSON on stdout.
# Runs niced in the background; the text is never logged or put in argv.
#   scan.sh <image-path>          (only files inside the plugin's image dir)
set -uo pipefail
umask 077
IMAGE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/timon.clipboard/images"
img=${1:-}
[[ $img == "$IMAGE_DIR"/* && -r $img ]] || exit 1

complete=true ocr="" qr=""
if command -v zbarimg >/dev/null; then
  qr=$(timeout 15s nice -n 19 zbarimg --quiet --raw -- "$img" 2>/dev/null | head -c 4096)
else
  complete=false
fi
if command -v tesseract >/dev/null; then
  langs=eng
  tesseract --list-langs 2>/dev/null | grep -qx deu && langs=eng+deu
  ocr=$(OMP_THREAD_LIMIT=1 timeout 30s nice -n 19 tesseract "$img" - -l "$langs" 2>/dev/null | head -c 8192)
else
  complete=false
fi
jq -cn --arg ocr "$ocr" --arg qr "$qr" --argjson complete "$complete" '{ocr: ($ocr | gsub("^\\s+|\\s+$"; "")), qr: ($qr | gsub("^\\s+|\\s+$"; "")), complete: $complete}'
