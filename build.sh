#!/bin/bash
# AppleOS master build. Works on any Linux distro:
# minimal downloads kernel + busybox itself, arch on foreign distros goes via docker.
# Usage: ./build.sh [all|arch|docker-arch|rootfs|initramfs|iso|clean]
set -euo pipefail
cd "$(dirname "$0")"

cmd="${1:-auto}"

case "$cmd" in
  auto)
    # No args — just build the ISO the best available way:
    # native mkarchiso on Arch, Docker container on other distros,
    # quick minimal if there is no Docker.
    if command -v mkarchiso >/dev/null 2>&1; then
      echo "[build] mkarchiso found — building full ISO (arch)"
      ./scripts/build-arch-iso.sh
    elif command -v docker >/dev/null 2>&1; then
      echo "[build] no mkarchiso, docker found — building full ISO in container"
      ./scripts/build-arch-docker.sh
    else
      echo "[build] neither mkarchiso nor docker — building minimal ISO"
      ./scripts/check-deps.sh
      ./scripts/build-rootfs.sh
      ./scripts/build-initramfs.sh
      ./scripts/build-iso.sh
      echo ""
      echo "=== DONE (minimal, rootless, downloaded kernel) ==="
      ls -lh build/initramfs.cpio.gz build/appleos-*.iso 2>/dev/null
      echo "Run: ./scripts/run-qemu.sh"
    fi
    ;;
  rootfs)    ./scripts/check-deps.sh && ./scripts/build-rootfs.sh ;;
  initramfs) ./scripts/check-deps.sh && ./scripts/build-initramfs.sh ;;
  iso)       ./scripts/check-deps.sh && ./scripts/build-iso.sh ;;
  arch)      ./scripts/build-arch-iso.sh ;;
  docker-arch) ./scripts/build-arch-docker.sh ;;
  all)
    ./scripts/check-deps.sh
    ./scripts/build-rootfs.sh
    ./scripts/build-initramfs.sh
    ./scripts/build-iso.sh
    echo ""
    echo "=== DONE (minimal, rootless, downloaded kernel) ==="
    ls -lh build/initramfs.cpio.gz build/appleos-*.iso 2>/dev/null
    echo "Run: ./scripts/run-qemu.sh"
    echo "Full Arch-based ISO: ./build.sh arch (Arch) or ./build.sh docker-arch (any distro)"
    ;;
  clean)
    rm -rf build 2>/dev/null || sudo rm -rf build
    echo "cleaned."
    ;;
  *) echo "usage: $0 [auto|all|arch|docker-arch|rootfs|initramfs|iso|clean]  (no args = auto)"; exit 1 ;;
esac
