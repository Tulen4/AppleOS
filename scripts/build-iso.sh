#!/bin/bash
# Builds a bootable ISO: DOWNLOADED Arch kernel + our initramfs + grub.
# No host files: identical ISO on any PC.
# Override the kernel: KERNEL=/path/to/vmlinuz ./build.sh iso
set -euo pipefail
cd "$(dirname "$0")/.."

source VERSION 2>/dev/null || { DISTRO_NAME="AppleOS"; VERSION="0.3.0"; }
OUT="build/appleos-${VERSION}.iso"
ISODIR="build/iso"
INITRAMFS="build/initramfs.cpio.gz"
KFETCH="build/kernel/vmlinuz-linux"

# 1. Kernel: KERNEL=... from env, else download the linux package from the official Arch CDN
# and extract vmlinuz from it (cached in build/kernel/).
KERNEL="${KERNEL:-}"
if [ -z "$KERNEL" ]; then
  if [ ! -f "$KFETCH" ]; then
    # Package cache: re-download a broken partial file
    if ! { [ -f build/kernel/pkg.tar.zst ] && bsdtar -tf build/kernel/pkg.tar.zst 2>/dev/null | grep -qE "vmlinuz$"; }; then
      rm -f build/kernel/pkg.tar.zst
      echo "[iso] resolving Arch kernel version..."
      KFILE="$(curl -fsSL --retry 3 --retry-all-errors --max-time 30 \
        "https://archlinux.org/packages/core/x86_64/linux/json/" | grep -o '"filename": "[^"]*"' | cut -d'"' -f4)"
      [ -n "$KFILE" ] || { echo "ERROR: could not resolve kernel version (network?)"; exit 1; }
      echo "[iso] downloading $KFILE (~170 MB, once, then cached)..."
      mkdir -p build/kernel
      curl -fSL --retry 3 --retry-all-errors -o "build/kernel/pkg.tar.zst" \
        "https://geo.mirror.pkgbuild.com/core/os/x86_64/$KFILE"
    else
      echo "[iso] cached kernel package OK"
    fi
    echo "[iso] extracting vmlinuz..."
    # Package layout changed over time: was boot/vmlinuz-linux,
    # now usr/lib/modules/<ver>/vmlinuz — locate dynamically.
    VMLINUZ_PATH="$(bsdtar -tf "build/kernel/pkg.tar.zst" 2>/dev/null | grep -E "vmlinuz$" | head -1)"
    [ -n "$VMLINUZ_PATH" ] || { echo "ERROR: vmlinuz not found in kernel package"; exit 1; }
    if command -v bsdtar >/dev/null 2>&1; then
      bsdtar -xf "build/kernel/pkg.tar.zst" -C build/kernel "$VMLINUZ_PATH"
    else
      tar -I zstd -xf "build/kernel/pkg.tar.zst" -C build/kernel "$VMLINUZ_PATH"
    fi
    mv "build/kernel/$VMLINUZ_PATH" "$KFETCH"
    rm -rf build/kernel/boot build/kernel/usr
  else
    echo "[iso] cached kernel: $KFETCH"
  fi
  KERNEL="$KFETCH"
fi
[ -f "$KERNEL" ] || { echo "ERROR: kernel not found: $KERNEL"; exit 1; }

[ -f "$INITRAMFS" ] || { echo "ERROR: no $INITRAMFS. Run ./build.sh initramfs first"; exit 1; }

command -v grub-mkrescue >/dev/null || { echo "ERROR: no grub-mkrescue. Run ./scripts/check-deps.sh"; exit 1; }

echo "[iso] kernel: $KERNEL"
echo "[iso] initramfs: $INITRAMFS"

rm -rf "$ISODIR"
mkdir -p "$ISODIR/boot/grub"
cp "$KERNEL" "$ISODIR/boot/vmlinuz"
cp "$INITRAMFS" "$ISODIR/boot/initramfs.cpio.gz"
cp grub/grub.cfg "$ISODIR/boot/grub/grub.cfg"
# Logo: original + 1920x1080 GRUB background (generated from logo.png)
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
" 2>/dev/null || echo "[iso] warn: splash not generated (no Pillow), continuing without background"

echo "[iso] grub-mkrescue -> $OUT ..."
grub-mkrescue -o "$OUT" "$ISODIR" 2>&1 | tail -5

echo "[iso] OK: $(du -h "$OUT" | cut -f1)  $OUT"
