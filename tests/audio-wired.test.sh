#!/bin/bash
# bash tests/audio-wired.test.sh   (omarchy-audio-wired on fixture outputs; no audio touched)
set -u
here=$(cd "$(dirname "$0")/.." && pwd); W=$here/overlay/.local/bin/omarchy-audio-wired
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME=$tmp/cfg AUDIO_WIRED_JSON=$tmp/sinks.json; mkdir -p "$tmp/cfg/omarchy"
sink() { # name api bus formfactor porttype availability
  jq -n --arg n "$1" --arg api "$2" --arg bus "$3" --arg ff "$4" --arg pt "$5" --arg av "$6" \
    '{name: $n, properties: ({"device.api": $api, "device.bus": $bus} + (if $ff == "" then {} else {"device.form_factor": $ff} end)), active_port: "p", ports: [{name: "p", type: $pt, availability: $av}]}'
}
{ sink alsa_output.usb-KTMicro_Chu2_DSP-00.analog-stereo alsa usb "" Analog "availability unknown"
  sink alsa_output.usb-Apple_USB-C_to_3.5mm_Headphone_Jack_Adapter-00.analog-stereo alsa usb headphone Headphones available
  sink alsa_output.usb-Logitech_USB_Speaker-00.analog-stereo alsa usb speaker Speaker "availability unknown"
  sink alsa_output.pci-0000_00_1f.3.HiFi__Headphones__sink alsa pci "" Headphones available
  sink alsa_output.pci-0000_00_1f.3.HiFi__Headphones2__sink alsa pci "" Headphones "not available"
  sink alsa_output.pci-0000_00_1f.3.HiFi__Speaker__sink alsa pci "" Speaker "availability unknown"
  sink alsa_output.pci-0000_00_1f.3.HiFi__HDMI1__sink alsa pci "" HDMI available
  sink bluez_output.AA_BB.1 bluez5 bluetooth headphone Headphones available
  sink omarchy_speaker_tuning "" "" "" "" ""
} | jq -s . >"$AUDIO_WIRED_JSON"
fail=0
t() { if "$W" "$2"; then r=yes; else r=no; fi; [[ $r == "$1" ]] && echo "ok   $1  $2" || { echo "FAIL want $1: $2"; fail=1; }; }
t yes alsa_output.usb-KTMicro_Chu2_DSP-00.analog-stereo
t yes alsa_output.usb-Apple_USB-C_to_3.5mm_Headphone_Jack_Adapter-00.analog-stereo
t no  alsa_output.usb-Logitech_USB_Speaker-00.analog-stereo
t yes alsa_output.pci-0000_00_1f.3.HiFi__Headphones__sink
t no  alsa_output.pci-0000_00_1f.3.HiFi__Headphones2__sink
t no  alsa_output.pci-0000_00_1f.3.HiFi__Speaker__sink
t no  alsa_output.pci-0000_00_1f.3.HiFi__HDMI1__sink
t no  bluez_output.AA_BB.1
t no  omarchy_speaker_tuning
t no  does-not-exist
echo 'SINK="Logitech"; NOT_SINK="KTMicro"' >"$tmp/cfg/omarchy/audio-passthrough.machine.conf"
t yes alsa_output.usb-Logitech_USB_Speaker-00.analog-stereo
t no  alsa_output.usb-KTMicro_Chu2_DSP-00.analog-stereo
exit $fail
