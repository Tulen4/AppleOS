#!/bin/bash
# Build AppleOS as an Arch-based Live ISO via mkarchiso. Needs sudo.
# Usage: ./scripts/build-arch-iso.sh  (or ./build.sh arch)
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="build/archiso"
OUT="build/arch-out"
MKWORK="build/mkwork"

# Pinned build epoch: makes the ISO uuid deterministic (mkarchiso derives it
# from SOURCE_DATE_EPOCH), so boot/grub/grub.cfg can bake the real uuid for Ventoy.
export SOURCE_DATE_EPOCH=1759276800
# Same formula as mkarchiso: TZ=UTC printf '%(%F-%H-%M-%S-00)T' $SOURCE_DATE_EPOCH
APPLEOS_UUID="$(TZ=UTC printf '%(%F-%H-%M-%S-00)T' "$SOURCE_DATE_EPOCH")"
echo "[arch] pinned epoch $SOURCE_DATE_EPOCH -> uuid $APPLEOS_UUID"

command -v mkarchiso >/dev/null || { echo "ERROR: no mkarchiso. On Arch: sudo pacman -S archiso. On another distro: ./scripts/build-arch-docker.sh"; exit 1; }
command -v repo-add >/dev/null || { echo "ERROR: no repo-add. On Arch: sudo pacman -S pacman-contrib. On another distro: ./scripts/build-arch-docker.sh"; exit 1; }
[ -d /usr/share/archiso/configs/releng ] || { echo "ERROR: no releng profile (archiso package). On another distro: ./scripts/build-arch-docker.sh"; exit 1; }

echo "[arch] preparing profile in $WORK ..."
# Previous workdirs belong to root (created under sudo) — clean via sudo if needed
clean_dir() { [ -e "$1" ] || return 0; rm -rf "$1" 2>/dev/null || sudo rm -rf "$1"; }
clean_dir "$WORK"
clean_dir "$OUT"
clean_dir "$MKWORK"
clean_dir ./work   # default workdir of old runs
mkdir -p "$WORK" "$OUT" "$MKWORK"
cp -a /usr/share/archiso/configs/releng/. "$WORK/"
# Overlay — our AppleOS files
cp -a arch-profile/profiledef.sh arch-profile/pacman.conf arch-profile/packages.x86_64 "$WORK/"
cp -a arch-profile/airootfs/. "$WORK/airootfs/"
# Logos always fresh from the repo root
mkdir -p "$WORK/airootfs/usr/share/pixmaps" "$WORK/airootfs/etc/calamares/branding/appleos" \
         "$WORK/airootfs/usr/share/fastfetch/logos" "$WORK/airootfs/etc/xdg/fastfetch" \
         "$WORK/airootfs/etc/skel/.config/fastfetch"
cp logo.png "$WORK/airootfs/usr/share/pixmaps/appleos-logo.png"
cp logo.png "$WORK/airootfs/etc/calamares/branding/appleos/logo.png"
cp fastfetch.txt "$WORK/airootfs/usr/share/fastfetch/logos/appleos.txt"
# Apple Shell: deploy configs (single source of truth is apple-shell/)
AS="apple-shell"
SK="$WORK/airootfs/etc/skel/.config"
SH="$WORK/airootfs/usr/share/apple-shell"
mkdir -p "$SK/labwc" "$SK/waybar" "$SK/fuzzel" "$SK/foot" "$SK/mako" "$SK/fontconfig" "$SK/swaylock" \
         "$SH/waybar" "$SH/labwc" "$SH/mako" "$SH/swayfx" "$SH/misc"
cp "$AS/labwc/rc.xml" "$AS/labwc/autostart" "$AS/labwc/environment" "$AS/labwc/menu.xml" "$SK/labwc/"
cp "$AS/labwc/themes/themerc-dark" "$SK/labwc/themerc-override"
cp "$AS/waybar/config-top.json" "$AS/waybar/config-dock.json" "$SK/waybar/"
cp "$AS"/waybar/style*.css "$SK/waybar/"
cp "$AS/fuzzel/fuzzel.ini" "$SK/fuzzel/"
cp "$AS/foot/foot.ini" "$SK/foot/"
cp "$AS/mako/config" "$SK/mako/config"
cp "$AS/fontconfig/fonts.conf" "$SK/fontconfig/"
cp "$AS/swaylock/config" "$SK/swaylock/config"
cp "$AS/misc/emoji.txt" "$SH/misc/"
cp "$AS"/wallpaper*.png "$SH/"
cp VERSION "$SH/VERSION"
cp "$AS"/waybar/style-*.css "$SH/waybar/"
cp "$AS/labwc/themes/themerc-"* "$SH/labwc/"
cp "$AS/mako/config-light" "$SH/mako/"
cp "$AS/swayfx/config" "$SH/swayfx/"
cp "$AS/scripts/apple-shell-settings" "$WORK/airootfs/usr/local/bin/apple-shell-settings"
cp "$AS/scripts/apple-shell-record" "$WORK/airootfs/usr/local/bin/apple-shell-record"
cp "$AS/scripts/apple-shell-shot" "$WORK/airootfs/usr/local/bin/apple-shell-shot"
cp "$AS/scripts/apple-shell-clip" "$WORK/airootfs/usr/local/bin/apple-shell-clip"
chmod +x "$SK/labwc/autostart" "$WORK/airootfs/usr/local/bin/apple-shell-settings" \
         "$WORK/airootfs/usr/local/bin/apple-shell-record" \
         "$WORK/airootfs/usr/local/bin/apple-shell-shot" \
         "$WORK/airootfs/usr/local/bin/apple-shell-clip"

# Rename boot entries Arch -> AppleOS (syslinux + grub + systemd-boot)
grep -rl "Arch Linux" "$WORK/syslinux" "$WORK/efiboot" "$WORK/grub" 2>/dev/null | xargs -r sed -i 's/Arch Linux/AppleOS/g' 2>/dev/null || true
grep -rl "archlinux" "$WORK/syslinux" "$WORK/efiboot" 2>/dev/null | xargs -r sed -i 's/archlinux/appleos/g' 2>/dev/null || true

# Boot branding: apple splash for the syslinux (BIOS) menu + `splash` on live
# kernel cmdlines so plymouth shows (syslinux APPEND + systemd-boot options).
python3 -c "
from PIL import Image
logo = Image.open('logo.png').convert('RGBA')
s = 1.5
logo = logo.resize((int(logo.width*s), int(logo.height*s)), Image.NEAREST)
bg = Image.new('RGB', (640, 480), (0, 0, 0))
bg.paste(logo, ((640-logo.width)//2, (480-logo.height)//2), logo)
bg.save('$WORK/syslinux/splash.png')
print('[arch] syslinux splash generated')
" 2>/dev/null || echo "[arch] warn: syslinux splash skipped (no Pillow)"
grep -rl "archisosearchuuid=%ARCHISO_UUID%" "$WORK/syslinux" "$WORK/efiboot" 2>/dev/null \
  | xargs -r sed -i 's/archisosearchuuid=%ARCHISO_UUID%/archisosearchuuid=%ARCHISO_UUID% splash/' 2>/dev/null || true

# Calamares with our configs: repacked package (otherwise pacstrap fails
# with "exists in filesystem": the overlay is copied first, and there is no --overwrite).
# PACMAN_CONFIG: resolve calamares via the profile config (it has the EndeavourOS repo).
export PACMAN_CONFIG="$(pwd)/$WORK/pacman.conf"
./scripts/mk-calamares-pkg.sh "$WORK"

echo "[arch] running mkarchiso (needs sudo, long build, ~1-2 GB downloads) ..."
# Our local packages are rebuilt on every run (sha256 changes),
# and pacstrap with -c would pick yesterday's copies from the shared cache and fail the checksum.
# Remove exactly the files our repo serves — the rest of the cache is untouched.
for _pkg in "$PWD"/build/pkg/*.pkg.tar.zst; do
  [ -f "$_pkg" ] && sudo rm -f "/var/cache/pacman/pkg/$(basename "$_pkg")"
done
sudo SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" mkarchiso -v -w "$MKWORK" -o "$OUT" "$WORK"

# Ventoy support: inject our own /boot/grub/grub.cfg (with the real uuid)
# so Ventoy uses it instead of its broken auto-generated menu.
./scripts/inject-ventoy-grub.sh "$OUT"/appleos-*.iso

echo ""
echo "=== DONE ==="
ls -lh "$OUT"/*.iso
