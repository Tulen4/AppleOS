#!/bin/bash
# Apple Shell — standalone installer. Works on any Arch-based system
# (Arch, EndeavourOS, Manjaro, CachyOS...), no AppleOS needed.
# Usage:
#   ./install.sh              install configs for current user (+ system share, needs sudo)
#   ./install.sh --user       only ~/.config, no root needed (needs /usr/share/apple-shell for themes)
#   ./install.sh --system     only system parts (/usr/share, /etc/skel, /usr/local/bin), needs root
#   ./install.sh --deps       only install packages via pacman, then exit
#   ./install.sh --uninstall  remove Apple Shell configs (backups are kept)
# Run from repo root (./apple-shell/install.sh) or from apple-shell/ (./install.sh).
set -u

SRC="$(cd "$(dirname "$0")" && pwd)"   # apple-shell/
MODE="auto"

for a in "$@"; do
  case "$a" in --user|--system|--deps|--uninstall|-h|--help) MODE="${a#--}";; *) echo "unknown: $a"; exit 1;; esac
done

if [ "$MODE" = h ] || [ "$MODE" = help ]; then
  sed -n '2,10p' "$0"; exit 0
fi

DEPS="labwc waybar fuzzel mako swaybg swaylock swayidle grim slurp wl-clipboard cliphist foot polkit-gnome xdg-desktop-portal-wlr xdg-desktop-portal-gtk papirus-icon-theme inter-font ttf-jetbrains-mono ttf-jetbrains-mono-nerd noto-fonts-emoji brightnessctl pamixer pavucontrol network-manager-applet capitaine-cursors"

install_deps() {
  command -v pacman >/dev/null || { echo "ERROR: pacman not found — install manually: $DEPS"; exit 1; }
  if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
  # shellcheck disable=SC2086
  $SUDO pacman -S --needed $DEPS
}

if [ "$MODE" = deps ]; then install_deps; exit 0; fi

if [ "$MODE" = uninstall ]; then
  rm -rf "$HOME/.config/labwc" "$HOME/.config/waybar" "$HOME/.config/fuzzel" \
         "$HOME/.config/foot" "$HOME/.config/mako" "$HOME/.config/swaylock" \
         "$HOME/.config/apple-shell"
  echo "user configs removed (system parts untouched; backups kept)"
  exit 0
fi

# --- user configs (~/.config) ---
deploy_user() {
  DST="$HOME/.config"
  BK="$HOME/.config-backup-$(date +%F-%H%M%S)-apple-shell"
  mkdir -p "$BK"
  for d in labwc waybar fuzzel foot mako fontconfig swaylock apple-shell; do
    [ -e "$DST/$d" ] && mv "$DST/$d" "$BK/$d"
  done
  echo "backup (if anything existed): $BK"
  mkdir -p "$DST/labwc" "$DST/waybar" "$DST/fuzzel" "$DST/foot" "$DST/mako" \
           "$DST/fontconfig" "$DST/swaylock" "$DST/apple-shell"
  cp "$SRC/labwc/rc.xml" "$SRC/labwc/autostart" "$SRC/labwc/environment" "$SRC/labwc/menu.xml" "$DST/labwc/"
  cp "$SRC/labwc/themes/themerc-dark" "$DST/labwc/themerc-override"
  cp "$SRC/waybar/config-top.json" "$SRC/waybar/config-dock.json" "$DST/waybar/"
  cp "$SRC/waybar/style.css" "$DST/waybar/style.css"
  # theme variants (settings app swaps them in)
  cp "$SRC"/waybar/style-*.css "$DST/waybar/" 2>/dev/null || true
  [ -f "$SRC/waybar/style-dock-dark.css" ] && cp "$SRC/waybar/style-dock-dark.css" "$DST/waybar/style-dock.css"
  cp "$SRC/fuzzel/fuzzel.ini" "$DST/fuzzel/"
  cp "$SRC/foot/foot.ini" "$DST/foot/"
  cp "$SRC/mako/config" "$DST/mako/config"
  cp "$SRC/fontconfig/fonts.conf" "$DST/fontconfig/"
  cp "$SRC/swaylock/config" "$DST/swaylock/config"
  cp "$SRC/misc/emoji.txt" "$DST/apple-shell/" 2>/dev/null || true
  chmod +x "$DST/labwc/autostart"
  echo "user configs installed to $DST"
}

# --- system parts (/usr/share, /etc/skel, /usr/local/bin) ---
deploy_system() {
  [ "$(id -u)" -eq 0 ] || { echo "system install needs root: rerun with sudo"; exit 1; }
  SH="/usr/share/apple-shell"
  mkdir -p "$SH/waybar" "$SH/labwc" "$SH/mako" "$SH/swayfx" "$SH/misc" \
           /etc/skel/.config /usr/local/bin /usr/share/pixmaps
  cp "$SRC"/wallpaper*.png "$SH/" 2>/dev/null || true
  cp "$SRC"/waybar/style-*.css "$SH/waybar/" 2>/dev/null || true
  cp "$SRC"/labwc/themes/themerc-* "$SH/labwc/" 2>/dev/null || true
  cp "$SRC/mako/config" "$SH/mako/" 2>/dev/null || true
  cp "$SRC/mako/config-light" "$SH/mako/" 2>/dev/null || true
  cp "$SRC/swayfx/config" "$SH/swayfx/" 2>/dev/null || true
  cp "$SRC/misc/emoji.txt" "$SH/misc/" 2>/dev/null || true
  [ -f "$SRC/../VERSION" ] && cp "$SRC/../VERSION" "$SH/VERSION"
  [ -f "$SRC/../logo.png" ] && cp "$SRC/../logo.png" /usr/share/pixmaps/appleos-logo.png
  for s in apple-shell-settings apple-shell-record apple-shell-shot apple-shell-clip; do
    cp "$SRC/scripts/$s" /usr/local/bin/$s
    chmod +x /usr/local/bin/$s
  done
  # future users get the shell out of the box
  for d in labwc waybar fuzzel foot mako fontconfig swaylock; do
    mkdir -p /etc/skel/.config/$d
  done
  cp "$SRC/labwc/rc.xml" "$SRC/labwc/autostart" "$SRC/labwc/environment" "$SRC/labwc/menu.xml" /etc/skel/.config/labwc/
  cp "$SRC/labwc/themes/themerc-dark" /etc/skel/.config/labwc/themerc-override
  cp "$SRC/waybar/config-top.json" "$SRC/waybar/config-dock.json" /etc/skel/.config/waybar/
  cp "$SRC/waybar/style.css" /etc/skel/.config/waybar/style.css
  cp "$SRC"/waybar/style-*.css /etc/skel/.config/waybar/ 2>/dev/null || true
  [ -f "$SRC/waybar/style-dock-dark.css" ] && cp "$SRC/waybar/style-dock-dark.css" /etc/skel/.config/waybar/style-dock.css
  cp "$SRC/fuzzel/fuzzel.ini" /etc/skel/.config/fuzzel/
  cp "$SRC/foot/foot.ini" /etc/skel/.config/foot/
  cp "$SRC/mako/config" /etc/skel/.config/mako/config
  cp "$SRC/fontconfig/fonts.conf" /etc/skel/.config/fontconfig/
  cp "$SRC/swaylock/config" /etc/skel/.config/swaylock/config
  chmod +x /etc/skel/.config/labwc/autostart
  echo "system parts installed ($SH, /etc/skel, /usr/local/bin)"
}

case "$MODE" in
  user) deploy_user;;
  system) deploy_system;;
  *)
    # auto: deps prompt + user configs + system share (needs sudo once)
    if command -v pacman >/dev/null && ! pacman -Q labwc waybar 2>/dev/null | grep -q . ; then
      read -rp "Install packages via pacman? [Y/n] " yn; yn="${yn:-Y}"
      if [ "$yn" = Y ] || [ "$yn" = y ]; then install_deps; fi
    fi
    deploy_user
    if [ "$(id -u)" -eq 0 ]; then deploy_system
    else
      echo "---"
      read -rp "Install system parts (/usr/share, /etc/skel, /usr/local/bin)? needs sudo [Y/n] " yn; yn="${yn:-Y}"
      if [ "$yn" = Y ] || [ "$yn" = y ]; then sudo "$0" --system; fi
    fi
    echo ""
    echo "Done. Log out, pick the labwc session, log in."
    ;;
esac
