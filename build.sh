#!/bin/bash
# AppleOS master build
set -euo pipefail
cd "$(dirname "$0")"

cmd="${1:-all}"

case "$cmd" in
  rootfs)    ./scripts/build-rootfs.sh ;;
  initramfs) ./scripts/build-initramfs.sh ;;
  iso)       ./scripts/build-iso.sh ;;
  arch)      ./scripts/build-arch-iso.sh ;;
  all)
    ./scripts/build-rootfs.sh
    ./scripts/build-initramfs.sh
    ./scripts/build-iso.sh
    echo ""
    echo "=== ГОТОВО (minimal, без root) ==="
    ls -lh build/initramfs.cpio.gz build/appleos-*.iso 2>/dev/null
    echo "Запуск: ./scripts/run-qemu.sh"
    echo "Полный Arch-based ISO: ./build.sh arch  (нужен sudo)"
    ;;
  clean)
    rm -rf build
    echo "cleaned."
    ;;
  *) echo "usage: $0 [rootfs|initramfs|iso|arch|all|clean]"; exit 1 ;;
esac
