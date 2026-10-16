#!/bin/bash
# Pause every MPRIS player in this session (Spotify, Brave/YouTube, Firefox, mpv, …).
set -u

pause_name() {
  local name=$1
  busctl --user call "$name" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Pause >/dev/null 2>&1 || true
}

omarchy-shell -q media pause >/dev/null 2>&1 || true

# Names currently on the bus, plus activatable ones Chromium-based browsers use.
{
  busctl --user list --acquired --no-legend 2>/dev/null | awk '{print $1}'
  busctl --user list --activatable --no-legend 2>/dev/null | awk '{print $1}'
} | grep -E '^org\.mpris\.MediaPlayer2\.' | sort -u | while read -r name; do
  pause_name "$name"
done
