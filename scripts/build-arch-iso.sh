#!/bin/bash
# Сборка AppleOS как Arch-based Live ISO через mkarchiso. Требует sudo.
# Использование: ./scripts/build-arch-iso.sh  (или ./build.sh arch)
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="build/archiso"
OUT="build/arch-out"
MKWORK="build/mkwork"

command -v mkarchiso >/dev/null || { echo "ERROR: нет mkarchiso. sudo pacman -S archiso"; exit 1; }
command -v repo-add >/dev/null || { echo "ERROR: нет repo-add. sudo pacman -S pacman-contrib"; exit 1; }

echo "[arch] preparing profile in $WORK ..."
# workdir прошлых запусков принадлежит root (создан под sudo) — чистим через sudo при нужде
clean_dir() { [ -e "$1" ] || return 0; rm -rf "$1" 2>/dev/null || sudo rm -rf "$1"; }
clean_dir "$WORK"
clean_dir "$OUT"
clean_dir "$MKWORK"
clean_dir ./work   # дефолтный workdir старых запусков
mkdir -p "$WORK" "$OUT" "$MKWORK"
cp -a /usr/share/archiso/configs/releng/. "$WORK/"
# Поверх — наши файлы AppleOS
cp -a arch-profile/profiledef.sh arch-profile/pacman.conf arch-profile/packages.x86_64 "$WORK/"
cp -a arch-profile/airootfs/. "$WORK/airootfs/"
# Лого всегда свежее из корня репо
mkdir -p "$WORK/airootfs/usr/share/pixmaps" "$WORK/airootfs/etc/calamares/branding/appleos" \
         "$WORK/airootfs/usr/share/fastfetch/logos" "$WORK/airootfs/etc/xdg/fastfetch" \
         "$WORK/airootfs/etc/skel/.config/fastfetch"
cp logo.png "$WORK/airootfs/usr/share/pixmaps/appleos-logo.png"
cp logo.png "$WORK/airootfs/etc/calamares/branding/appleos/logo.png"
cp fastfetch.txt "$WORK/airootfs/usr/share/fastfetch/logos/appleos.txt"

# Переименовать пункты загрузки Arch -> AppleOS (syslinux + grub + systemd-boot)
grep -rl "Arch Linux" "$WORK/syslinux" "$WORK/efiboot" "$WORK/grub" 2>/dev/null | xargs -r sed -i 's/Arch Linux/AppleOS/g' 2>/dev/null || true
grep -rl "archlinux" "$WORK/syslinux" "$WORK/efiboot" 2>/dev/null | xargs -r sed -i 's/archlinux/appleos/g' 2>/dev/null || true

# Calamares с нашими конфигами: перепаковка пакета (иначе pacstrap падает
# с "exists in filesystem": overlay копируется раньше, а --overwrite там нет).
./scripts/mk-calamares-pkg.sh "$WORK"

echo "[arch] running mkarchiso (нужен sudo, долгая сборка, ~1-2 ГБ загрузок) ..."
# Наш перепакованный calamares собирается заново при каждом прогоне (меняется sha256),
# а pacstrap с -c подхватил бы вчерашнюю копию из общего кэша и упал бы на checksum.
# Маска только наши файлы — остальной кэш не трогаем.
sudo rm -f /var/cache/pacman/pkg/calamares-*appleos1*.pkg.tar.zst
sudo mkarchiso -v -w "$MKWORK" -o "$OUT" "$WORK"

echo ""
echo "=== ГОТОВО ==="
ls -lh "$OUT"/*.iso
