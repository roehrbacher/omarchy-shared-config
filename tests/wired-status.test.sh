#!/bin/bash
# bash tests/wired-status.test.sh   (omarchy-wired-status on a fake sysfs + fake nmcli/ip)
set -u
here=$(cd "$(dirname "$0")/.." && pwd); W=$here/overlay/.local/bin/omarchy-wired-status
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export WIRED_SYSFS=$tmp/net PATH=$tmp/bin:$PATH; mkdir -p "$tmp/bin" "$tmp/dev/pci/eth" "$tmp/dev/pci/usb1/1-2/net"
mk() { # iface carrier devpath [wireless]
  local d=$tmp/net/$1; mkdir -p "$d/statistics"; echo 1 >"$d/type"; echo "$2" >"$d/carrier"
  echo 1000 >"$d/speed"; echo 2048 >"$d/statistics/rx_bytes"; echo 1024 >"$d/statistics/tx_bytes"
  ln -s "$3" "$d/device"; [[ ${4:-} ]] && mkdir "$d/wireless"; true
}
mk eno1 1 "$tmp/dev/pci/eth"
mk enp0s20f0u2 1 "$tmp/dev/pci/usb1/1-2/net"
mk enp3s0 0 "$tmp/dev/pci/eth"
mk wlan0 1 "$tmp/dev/pci/eth" w
mkdir -p "$tmp/net/lo"; echo 772 >"$tmp/net/lo/type"
cat >"$tmp/bin/nmcli" <<'N'
#!/bin/bash
case "$*" in
  "-t -f DEVICE,TYPE,STATE device") printf 'eno1:ethernet:connected\nenp0s20f0u2:ethernet:disconnected\nenp3s0:ethernet:unavailable\nwlan0:wifi:connected\n' ;;
  *"device show eno1") printf 'GENERAL.CONNECTION:Wired connection 1\nIP4.ADDRESS[1]:192.0.2.10/24\nIP4.GATEWAY:192.0.2.1\nIP4.DNS[1]:192.0.2.53\nIP4.DNS[2]:198.51.100.53\n' ;;
  *"device show"*) printf 'GENERAL.CONNECTION:\n' ;;
  "device disconnect eno1") echo "$*" >"$NMLOG" ;;
esac
N
printf '#!/bin/sh\necho %s\n' "'[{\"dev\":\"eno1\"}]'" >"$tmp/bin/ip"; chmod +x "$tmp/bin/"*
export NMLOG=$tmp/nmlog
out=$("$W"); fail=0
ok() { if [[ $(jq -c "$1" <<<"$out") == "$2" ]]; then echo "ok   $3"; else echo "FAIL $3: $(jq -c "$1" <<<"$out")"; fail=1; fi; }
ok '[.[].iface]' '["eno1","enp0s20f0u2"]' "only plugged-in wired links (no unplugged LAN, no Wi-Fi, no lo)"
ok '[.[].kind]' '["lan","usb"]' "USB tether detected"
ok '.[0] | [.name,.state,.ip,.prefix,.gateway,.speed,.default]' '["Wired connection 1","connected","192.0.2.10","24","192.0.2.1",1000,true]' "LAN details"
ok '.[0].dns' '["192.0.2.53","198.51.100.53"]' "DNS list"
ok '.[1].state' '"off"' "switched-off tether still listed"
"$W" off eno1 && [[ $(cat "$NMLOG") == "device disconnect eno1" ]] && echo "ok   off -> nmcli disconnect" || { echo "FAIL off"; fail=1; }
"$W" off wlan0 2>/dev/null; [[ $? == 1 ]] && echo "ok   non-wired rejected" || { echo "FAIL reject"; fail=1; }
exit $fail
