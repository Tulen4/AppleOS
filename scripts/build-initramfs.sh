#!/bin/bash
# Packs build/rootfs -> build/initramfs.cpio.gz (newc, with /init at root)
set -euo pipefail
cd "$(dirname "$0")/.."

ROOTFS="build/rootfs"
OUT="build/initramfs.cpio.gz"

[ -d "$ROOTFS" ] || { echo "ERROR: no $ROOTFS. Run ./build.sh rootfs first"; exit 1; }
[ -x "$ROOTFS/init" ] || { echo "ERROR: $ROOTFS/init is not executable"; exit 1; }

echo "[initramfs] packing $ROOTFS -> $OUT ..."
(
  cd "$ROOTFS"
  find . -print0 | cpio --quiet --format=newc --create --null
) | gzip -9 > "$OUT"

echo "[initramfs] OK: $(du -h "$OUT" | cut -f1)  $OUT"
