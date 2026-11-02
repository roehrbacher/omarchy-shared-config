#!/bin/bash
# bash tests/audio-passthrough-source.test.sh   (mic choice of omarchy-audio-passthrough; fake pactl/systemctl, no audio touched)
set -u
here=$(cd "$(dirname "$0")/.." && pwd); T=$here/overlay/.local/bin/omarchy-audio-passthrough
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/cfg PATH=$tmp/bin:$PATH; mkdir -p "$tmp/cfg/omarchy" "$tmp/bin"
cat >"$tmp/bin/pactl" <<'P'
#!/bin/bash
case "$1 $2" in
  "get-default-source "*) echo alsa_input.builtin ;;
  "get-default-sink "*) echo some_sink ;;
  "list sources") printf '\tName: alsa_input.builtin\n\tDescription: Built-in Mic\n\tName: alsa_input.usb-Headset\n\tDescription: USB Headset\n\tName: some_sink.monitor\n\tDescription: Monitor\n' ;;
esac
P
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/systemctl"; cp "$tmp/bin/systemctl" "$tmp/bin/omarchy-audio-input-set-default"
chmod +x "$tmp/bin/"*
fail=0
ok() { if [[ $1 == "$2" ]]; then echo "ok   $3"; else echo "FAIL $3: got $1"; fail=1; fi; }
ok "$("$T" status | jq -r .source)" alsa_input.builtin "no setting: system default"
ok "$("$T" sources | jq -c '[.[].name]')" '["alsa_input.builtin","alsa_input.usb-Headset"]' "monitors not listed"
"$T" source alsa_input.usb-Headset >/dev/null
ok "$(grep -c '^SOURCE=alsa_input.usb-Headset$' "$tmp/cfg/omarchy/audio-passthrough.conf")" 1 "SOURCE saved in conf"
ok "$("$T" status | jq -r '.source + " " + .sourceSetting')" "alsa_input.usb-Headset alsa_input.usb-Headset" "chosen mic used"
ok "$("$T" sources | jq -c '[.[] | select(.current) | .name] + [.[] | select(.default) | .name]')" '["alsa_input.usb-Headset","alsa_input.builtin"]' "current vs default flags"
sed -i 's/^SOURCE=.*/SOURCE=alsa_input.gone/' "$tmp/cfg/omarchy/audio-passthrough.conf"
ok "$("$T" status | jq -r .source)" alsa_input.builtin "unplugged choice falls back to default"
"$T" source default >/dev/null
ok "$("$T" status | jq -r .sourceSetting)" "" "source default clears it"
"$T" source nope >/dev/null 2>&1; ok $? 1 "unknown mic rejected"
exit $fail
