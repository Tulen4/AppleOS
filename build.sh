#!/bin/bash
# AppleOS master build. Работает на любом дистрибутиве Linux:
# minimal качает ядро и busybox сам, arch на чужой дистре — через docker.
# Использование: ./build.sh [all|arch|docker-arch|rootfs|initramfs|iso|clean]
set -euo pipefail
cd "$(dirname "$0")"

cmd="${1:-auto}"

case "$cmd" in
  auto)
    # Без аргументов — просто собираем исошку лучшим доступным способом:
    # на Arch родным mkarchiso, на любом другом дистре через Docker,
    # без Docker — быстрый minimal.
    if command -v mkarchiso >/dev/null 2>&1; then
      echo "[build] mkarchiso найден — собираем полный ISO (arch)"
      ./scripts/build-arch-iso.sh
    elif command -v docker >/dev/null 2>&1; then
      echo "[build] mkarchiso нет, есть docker — собираем полный ISO в контейнере"
      ./scripts/build-arch-docker.sh
    else
      echo "[build] нет ни mkarchiso, ни docker — собираем minimal ISO"
      ./scripts/check-deps.sh
      ./scripts/build-rootfs.sh
      ./scripts/build-initramfs.sh
      ./scripts/build-iso.sh
      echo ""
      echo "=== ГОТОВО (minimal, без root, ядро скачано) ==="
      ls -lh build/initramfs.cpio.gz build/appleos-*.iso 2>/dev/null
      echo "Запуск: ./scripts/run-qemu.sh"
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
    echo "=== ГОТОВО (minimal, без root, ядро скачано) ==="
    ls -lh build/initramfs.cpio.gz build/appleos-*.iso 2>/dev/null
    echo "Запуск: ./scripts/run-qemu.sh"
    echo "Полный Arch-based ISO: ./build.sh arch (Arch) или ./build.sh docker-arch (любой дистр)"
    ;;
  clean)
    rm -rf build 2>/dev/null || sudo rm -rf build
    echo "cleaned."
    ;;
  *) echo "usage: $0 [auto|all|arch|docker-arch|rootfs|initramfs|iso|clean]  (без аргументов = auto)"; exit 1 ;;
esac
