#!/usr/bin/env bash
# Copy this repo's overlay/ into $HOME after backing up everything it touches.
# Repo-specific settings live in repo.conf next to this file.
#   ./install.sh            install
#   ./install.sh --dry-run  list what would change
set -euo pipefail

# Safety check: block commits with secrets/MACs/Tailscale IPs (.githooks/pre-commit).
git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" config core.hooksPath .githooks 2>/dev/null || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$ROOT/overlay"
DRY=0
[[ ${1:-} == --dry-run ]] && DRY=1

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "Do not run this as root." >&2
  exit 1
fi
if ! command -v omarchy >/dev/null 2>&1; then
  echo "Omarchy is not installed yet. Finish the Omarchy install first." >&2
  exit 1
fi

REMOVE_PATHS=()
EXTRA_BACKUP=()
PACKAGES=()
post_install() { :; }
# shellcheck source=/dev/null
source "$ROOT/repo.conf"

RETIRED="$HOME/.local/state/omarchy-config/retired-plugins"
retired() { [[ -f $RETIRED ]] && awk '{print $1}' "$RETIRED" | grep -qxF "$1"; }

STAMP=$(date +%Y-%m-%d-%H%M%S)
BACKUP_ROOT="$HOME/.local/share/omarchy-config-backups/$REPO_NAME"
BACKUP="$BACKUP_ROOT/$STAMP"
ADDED="$BACKUP/ADDED.txt"

# Overlay files, with each plugin folder treated as one unit.
mapfile -d '' FILES < <(cd "$OVERLAY" && find . -path ./.config/omarchy/plugins -prune -o -type f -print0 | sed -z 's|^\./||')
PLUGINS=()
if [[ -d $OVERLAY/.config/omarchy/plugins ]]; then
  for d in "$OVERLAY"/.config/omarchy/plugins/*/; do
    id=$(basename "$d")
    if retired "$id"; then echo "Skipping retired plugin $id"; continue; fi
    PLUGINS+=(".config/omarchy/plugins/$id")
  done
fi

# Packages from repo.conf: only missing ones are installed (pacman --needed,
# AUR through yay). Nothing is ever upgraded or removed; a failure is skipped.
install_packages() {
  local pkg missing=() repo=() aur=()
  for pkg in "${PACKAGES[@]}"; do
    pacman -Q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  (( ${#missing[@]} )) || return 0
  if ! sudo -n true 2>/dev/null && [[ ! -t 0 ]]; then
    echo "Not installing packages (sudo needs a password, no terminal): ${missing[*]}"
    echo "  Run ./install.sh in a terminal, or: sudo pacman -S --needed <pkg>"
    return 0
  fi
  for pkg in "${missing[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then repo+=("$pkg"); else aur+=("$pkg"); fi
  done
  for pkg in "${repo[@]}"; do
    echo "Installing package $pkg"
    sudo pacman -S --needed --noconfirm "$pkg" >/dev/null || echo "Could not install $pkg, skipping it"
  done
  for pkg in "${aur[@]}"; do
    if ! command -v yay >/dev/null; then echo "Could not install $pkg (AUR, yay missing), skipping it"; continue; fi
    echo "Installing AUR package $pkg"
    yay -S --needed --noconfirm "$pkg" >/dev/null || echo "Could not install $pkg (AUR), skipping it"
  done
  return 0
}

if (( DRY )); then
  for pkg in "${PACKAGES[@]}"; do
    pacman -Q "$pkg" >/dev/null 2>&1 || echo "package $pkg"
  done
  printf 'copy   ~/%s\n' "${FILES[@]}" "${PLUGINS[@]}"
  printf 'remove ~/%s\n' "${REMOVE_PATHS[@]}"
  exit 0
fi

mkdir -p "$BACKUP"
: >"$ADDED"
backup() {
  local rel=$1
  if [[ -e $HOME/$rel || -L $HOME/$rel ]]; then
    mkdir -p "$BACKUP/files/$(dirname "$rel")"
    cp -a "$HOME/$rel" "$BACKUP/files/$rel"
  else
    printf '%s\n' "$rel" >>"$ADDED"
  fi
}

echo "Backing up to $BACKUP"
for rel in "${FILES[@]}" "${PLUGINS[@]}" "${EXTRA_BACKUP[@]}" "${REMOVE_PATHS[@]}"; do
  backup "$rel"
done
echo "$BACKUP" >"$BACKUP_ROOT/LATEST"

echo "Copying overlay"
for rel in "${FILES[@]}"; do
  mkdir -p "$HOME/$(dirname "$rel")"
  cp -a "$OVERLAY/$rel" "$HOME/$rel"
done
for rel in "${PLUGINS[@]}"; do
  rm -rf "${HOME:?}/$rel"
  mkdir -p "$HOME/$(dirname "$rel")"
  cp -a "$OVERLAY/$rel" "$HOME/$rel"
done
for rel in "${REMOVE_PATHS[@]}"; do
  [[ -e $HOME/$rel || -L $HOME/$rel ]] && { echo "Removing ~/$rel"; rm -rf "${HOME:?}/$rel"; }
done

for rel in "${FILES[@]}"; do
  case $rel in
  .local/bin/* | .config/omarchy/hooks/*) chmod +x "$HOME/$rel" ;;
  esac
done

command -v systemctl >/dev/null && systemctl --user daemon-reload || true
install_packages
post_install

if command -v omarchy-shell-json-build >/dev/null || [[ -x $HOME/.local/bin/omarchy-shell-json-build ]]; then
  "$HOME/.local/bin/omarchy-shell-json-build" --no-reload || true
fi
command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
command -v omarchy-restart-shell >/dev/null && omarchy-restart-shell >/dev/null 2>&1 || true

echo
echo "Done. Backup: $BACKUP"
echo "Undo: $ROOT/uninstall.sh"
