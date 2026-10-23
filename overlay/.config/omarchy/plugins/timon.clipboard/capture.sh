#!/bin/bash

# timon.clipboard: captures the current clipboard as one JSON line on stdout.
# In watch mode wl-paste runs this with the payload on stdin and the mime as $1;
# without arguments it snapshots the current selection itself.
# Based on Omarchy's stock shell/plugins/clipboard/capture.sh.
#
# Nothing is captured while private mode is on, for password-manager copies
# (x-kde-passwordManagerHint, CLIPBOARD_STATE=sensitive), or for very large
# payloads. Files are written user-only (umask 077). Nothing is ever logged.

set -o pipefail
umask 077

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/timon.clipboard"
IMAGE_DIR="$DATA_DIR/images"
STATE_FILE="$DATA_DIR/state.json"
MAX_TEXT_BYTES=$((4 * 1024 * 1024))
MAX_IMAGE_BYTES=$((25 * 1024 * 1024))

mkdir -p "$IMAGE_DIR"
chmod 700 "$DATA_DIR" "$IMAGE_DIR" 2>/dev/null

# Window class of the app copied from (search app:<name>); empty if unknown.
APP=$(timeout 1s hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' 2>/dev/null | head -c 64)
export APP

drain() { cat >/dev/null 2>&1 || true; }

if [[ -r $STATE_FILE ]] && jq -e '.private == true' "$STATE_FILE" >/dev/null 2>&1; then
  [[ -n ${1:-} ]] && drain
  exit 0
fi

types=$(wl-paste --list-types 2>/dev/null || true)

# Password managers: Bitwarden desktop (arboard >= 3.6 exclude_from_history),
# KeePassXC and `wl-copy --sensitive` offer the x-kde-passwordManagerHint
# type ("secret"). wl-paste >= 2.3.0 then sets CLIPBOARD_STATE=sensitive for
# the watch command, which is also what makes fluxd skip the copy. The type
# list check covers the snapshot path and older wl-paste. No other heuristics.
if [[ ${CLIPBOARD_STATE:-} == "sensitive" ]] || grep -qx 'x-kde-passwordManagerHint' <<<"$types"; then
  [[ -n ${1:-} ]] && drain
  exit 0
fi

emit_image() {
  local mime="$1"
  local ext tmp hash file

  ext=${mime#image/}
  [[ $ext == jpeg ]] && ext=jpg

  tmp=$(mktemp --tmpdir="$IMAGE_DIR" clipboard.XXXXXX) || return 0
  head -c $((MAX_IMAGE_BYTES + 1)) >"$tmp"
  drain
  if [[ ! -s $tmp || $(stat -c %s "$tmp") -gt $MAX_IMAGE_BYTES ]]; then
    rm -f "$tmp"
    return 0
  fi

  hash=$(sha256sum "$tmp" | awk '{print $1}')
  file="$IMAGE_DIR/$hash.$ext"
  if [[ -e $file ]]; then
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi

  # A screenshot tool offers only image data; a browser "Copy image" also
  # offers text/html, a source URL or text/x-moz-url, so that is an image.
  local screenshot=true
  grep -qvE '^image/' <<<"$types" && screenshot=false

  jq -cn --arg mime "$mime" --arg path "$file" --arg captured_at "$(date +'%A %H:%M')" \
    --argjson bytes "$(stat -c %s "$file")" --argjson screenshot "$screenshot" --arg app "$APP" \
    '{type:"image", mime:$mime, path:$path, capturedAt:$captured_at, bytes:$bytes, screenshot:$screenshot} + (if $app != "" then {app:$app} else {} end)'
}

# 1.17.0: a browser / office copy also offers text/html. Keep it (up to
# 256 KiB, only when it has real formatting: headings, links, lists, bold,
# italic, code, tables) so "Paste as Markdown" can convert it later. Written
# to a user-only temp file for perl, never to argv or the environment.
MAX_HTML_BYTES=$((256 * 1024))
HTML_FILE=""
grab_html() {
  grep -qx 'text/html' <<<"$types" || return 0
  HTML_FILE=$(mktemp --tmpdir="$DATA_DIR" html.XXXXXX) || { HTML_FILE=""; return 0; }
  timeout 2s wl-paste --type text/html 2>/dev/null | head -c $((MAX_HTML_BYTES + 1)) >"$HTML_FILE"
  if [[ $(stat -c %s "$HTML_FILE") -gt $MAX_HTML_BYTES ]] || ! grep -qiE '<(h[1-6]|a|li|b|strong|em|i|code|pre|table|blockquote)[ >]' "$HTML_FILE"; then
    : >"$HTML_FILE"
  fi
}

emit_text() {
  grab_html
  HTML_FILE=$HTML_FILE MAX_TEXT_BYTES=$MAX_TEXT_BYTES perl -MEncode=decode,FB_CROAK,LEAVE_SRC -MJSON::PP=encode_json -0777 -e '
    my $raw = <STDIN>;
    exit unless length $raw;
    exit if length($raw) > $ENV{MAX_TEXT_BYTES};

    my $encoding;
    my $heuristic_encoding = 0;
    if ($raw =~ /^(?:\xFF\xFE|\xFE\xFF)/) {
      $encoding = "UTF-16";
    } elsif (length($raw) % 2 == 0 && index($raw, "\0") >= 0) {
      my $units = length($raw) / 2;
      my $nuls = $raw =~ tr/\0/\0/;

      # Neither byte lane can reach the padding threshold when the entire
      # payload contains fewer NULs than that, so avoid two full string passes.
      if ($nuls * 4 >= $units * 3) {
        my $even_bytes = $raw;
        $even_bytes =~ s/(.)./$1/sg;
        my $even_nuls = $even_bytes =~ tr/\0/\0/;
        undef $even_bytes;

        my $odd_bytes = $raw;
        $odd_bytes =~ s/.(.)/$1/sg;
        my $odd_nuls = $odd_bytes =~ tr/\0/\0/;

        # BOM-less UTF-16 is indistinguishable from NUL-separated bytes. Decode
        # only when at least three quarters of the code units have consistent
        # padding and fewer than one quarter have NULs in the opposite byte.
        if ($odd_nuls * 4 >= $units * 3 && $even_nuls * 4 < $units) {
          $encoding = "UTF-16LE";
          $heuristic_encoding = 1;
        } elsif ($even_nuls * 4 >= $units * 3 && $odd_nuls * 4 < $units) {
          $encoding = "UTF-16BE";
          $heuristic_encoding = 1;
        }
      }
    }

    my $text = $encoding ? eval { decode($encoding, $raw, FB_CROAK | LEAVE_SRC) } : undef;
    if ($heuristic_encoding && defined($text) && $text =~ /[\x00-\x08\x0E-\x1A\x1C-\x1F]/) {
      $text = undef;
    }
    $text = decode("UTF-8", $raw) unless defined $text;
    my $app = defined $ENV{APP} && length $ENV{APP} ? ",\"app\":" . encode_json(decode("UTF-8", $ENV{APP})) : "";
    my $html = "";
    if (length $ENV{HTML_FILE} && open(my $fh, "<", $ENV{HTML_FILE})) {
      local $/; my $h = <$fh>; close $fh;
      $h = eval { decode("UTF-8", $h, FB_CROAK) } if defined $h && length $h;
      $html = ",\"html\":" . encode_json($h) if defined $h && length $h;
    }
    print "{\"type\":\"text\",\"text\":", encode_json($text), $html, $app, "}\n";
  '
  local rc=$?
  [[ -n $HTML_FILE ]] && rm -f "$HTML_FILE"
  return $rc
}

# One copy that offers an image (browser "Copy image": image/png + text/html +
# a URL) wakes both watchers; keep only the image, not a separate link entry.
has_image() { grep -q '^image/' <<<"$types"; }

# 1.18.0: "Paste as Markdown" puts the converted text on the clipboard only
# to paste it; clipboard.sh leaves its hash in skip-next (valid 15 s). That
# one copy is dropped; any other copy is captured as usual.
SKIP_FILE="$DATA_DIR/skip-next"
skip_own_paste() {
  [[ -s $SKIP_FILE ]] && (( $(date +%s) - $(stat -c %Y "$SKIP_FILE") <= 15 )) || return 1
  local tmp sum
  tmp=$(mktemp --tmpdir="$DATA_DIR" own.XXXXXX) || return 1
  head -c $((MAX_TEXT_BYTES + 1)) >"$tmp"
  sum=$(sha256sum "$tmp" | awk '{print $1}')
  if [[ $sum == "$(cat "$SKIP_FILE")" ]]; then rm -f "$tmp" "$SKIP_FILE"; return 0; fi
  emit_text <"$tmp"; rm -f "$tmp"; return 0
}

case "${1:-}" in
text) if has_image; then drain; elif skip_own_paste; then :; else emit_text; fi; exit 0 ;;
image/*) emit_image "$1"; exit 0 ;;
esac

for mime in image/png image/jpeg image/webp image/gif image/bmp image/tiff; do
  if grep -qx "$mime" <<<"$types"; then
    timeout 2s wl-paste --type "$mime" 2>/dev/null | emit_image "$mime"
    exit 0
  fi
done

if grep -q '^text/' <<<"$types" || grep -qx 'UTF8_STRING' <<<"$types" || grep -qx 'STRING' <<<"$types"; then
  wl-paste --type text --no-newline 2>/dev/null | emit_text
fi
