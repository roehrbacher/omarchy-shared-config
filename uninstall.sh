#!/usr/bin/env bash
# Put back what the last ./install.sh of this repo replaced.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pre_uninstall() { :; }
# shellcheck source=/dev/null
source "$ROOT/repo.conf"

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "Do not run this as root." >&2
  exit 1
fi

BACKUP_ROOT="$HOME/.local/share/omarchy-config-backups/$REPO_NAME"
[[ -f $BACKUP_ROOT/LATEST ]] || { echo "No backup found for $REPO_NAME." >&2; exit 1; }
BACKUP=$(<"$BACKUP_ROOT/LATEST")
[[ -d $BACKUP ]] || { echo "Missing backup folder: $BACKUP" >&2; exit 1; }

echo "Restoring $BACKUP"
pre_uninstall

if [[ -f $BACKUP/ADDED.txt ]]; then
  while IFS= read -r rel; do
    [[ -n $rel ]] && rm -rf "${HOME:?}/$rel"
  done <"$BACKUP/ADDED.txt"
fi

if [[ -d $BACKUP/files ]]; then
  # Plugin folders are restored whole so no file from the overlay is left behind.
  for d in "$BACKUP"/files/.config/omarchy/plugins/*/; do
    [[ -d $d ]] && rm -rf "$HOME/.config/omarchy/plugins/$(basename "$d")"
  done
  cp -a "$BACKUP/files/." "$HOME/"
fi

command -v systemctl >/dev/null && systemctl --user daemon-reload || true
command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
command -v omarchy-restart-shell >/dev/null && omarchy-restart-shell >/dev/null 2>&1 || true
echo "Done. Restored from $BACKUP"
