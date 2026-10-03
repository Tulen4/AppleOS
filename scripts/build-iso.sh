#!/bin/bash
# Собирает bootable ISO: ядро хоста + наш initramfs + grub
set -euo pipefail
cd "$(dirname "$0")/.."

source VERSION 2>/dev/null || { DISTRO_NAME="AppleOS"; VERSION="0.1.0"; }
OUT="build/appleos-${VERSION}.iso"
ISODIR="build/iso"
INITRAMFS="build/initramfs.cpio.gz"

# 1. Ядро: KERNEL=... извне, иначе /boot/vmlinuz-linux, иначе ищем любое vmlinuz*
KERNEL="${KERNEL:-}"
if [ -z "$KERNEL" ]; then
  for k in /boot/vmlinuz-linux "/boot/vmlinuz-$(uname -r)" /boot/vmlinuz*; do
    [ -f "$k" ] && { KERNEL="$k"; break; }
  done
fi
[ -n "$KERNEL" ] && [ -f "$KERNEL" ] || { echo "ERROR: ядро не найдено. Укажи KERNEL=/path/to/vmlinuz ./build.sh iso"; exit 1; }

[ -f "$INITRAMFS" ] || { echo "ERROR: $INITRAMFS нет. Сначала ./build.sh initramfs"; exit 1; }

command -v grub-mkrescue >/dev/null || { echo "ERROR: нет grub-mkrescue. sudo pacman -S grub xorriso"; exit 1; }

echo "[iso] kernel: $KERNEL"
echo "[iso] initramfs: $INITRAMFS"

rm -rf "$ISODIR"
mkdir -p "$ISODIR/boot/grub"
cp "$KERNEL" "$ISODIR/boot/vmlinuz"
cp "$INITRAMFS" "$ISODIR/boot/initramfs.cpio.gz"
cp grub/grub.cfg "$ISODIR/boot/grub/grub.cfg"
# Лого: оригинал + splash 1920x1080 для фона GRUB (генерируется из logo.png)
cp logo.png "$ISODIR/boot/appleos-logo.png"
python3 -c "
from PIL import Image
logo = Image.open('logo.png').convert('RGBA')
s = 4
logo = logo.resize((logo.width*s, logo.height*s), Image.NEAREST)
bg = Image.new('RGB', (1920,1080), (0,0,0))
bg.paste(logo, ((1920-logo.width)//2, (1080-logo.height)//2), logo)
bg.save('$ISODIR/boot/grub/splash.png')
print('[iso] splash generated')
" 2>/dev/null || echo "[iso] warn: splash не сгенерирован (нет Pillow), едем без фона"

echo "[iso] grub-mkrescue -> $OUT ..."
grub-mkrescue -o "$OUT" "$ISODIR" 2>&1 | tail -5

echo "[iso] OK: $(du -h "$OUT" | cut -f1)  $OUT"
