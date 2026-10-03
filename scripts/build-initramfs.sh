#!/bin/bash
# Пакует build/rootfs -> build/initramfs.cpio.gz (newc, с /init в корне)
set -euo pipefail
cd "$(dirname "$0")/.."

ROOTFS="build/rootfs"
OUT="build/initramfs.cpio.gz"

[ -d "$ROOTFS" ] || { echo "ERROR: $ROOTFS нет. Сначала ./build.sh rootfs"; exit 1; }
[ -x "$ROOTFS/init" ] || { echo "ERROR: $ROOTFS/init не исполняемый"; exit 1; }

echo "[initramfs] packing $ROOTFS -> $OUT ..."
(
  cd "$ROOTFS"
  find . -print0 | cpio --quiet --format=newc --create --null
) | gzip -9 > "$OUT"

echo "[initramfs] OK: $(du -h "$OUT" | cut -f1)  $OUT"
