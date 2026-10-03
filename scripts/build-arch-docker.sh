#!/bin/bash
# Сборка Arch-based AppleOS ISO внутри Docker-контейнера с чистым Arch.
# Работает на ЛЮБОМ дистрибутиве Linux — нужен только Docker.
# Использование: ./scripts/build-arch-docker.sh
# На выходе: build/arch-out/*.iso (права возвращаются владельцу проекта).
set -euo pipefail
cd "$(dirname "$0")/.."

command -v docker >/dev/null || {
  echo "ERROR: нет docker."
  echo "  Arch:   sudo pacman -S docker && sudo systemctl enable --now docker"
  echo "  Ubuntu: sudo apt install docker.io && sudo systemctl enable --now docker"
  echo "  Fedora: sudo dnf install docker && sudo systemctl enable --now docker"
  exit 1
}

echo "[docker] building AppleOS arch ISO in archlinux:latest container..."
echo "[docker] (первый раз тянет образ ~1 ГБ и пакеты ~2 ГБ, дальше кэш)"
docker run --rm --privileged \
  -v "$PWD:/work" -w /work \
  archlinux:latest \
  bash -c '
    set -e
    pacman -Sy --noconfirm --needed archiso sudo grub xorriso squashfs-tools \
      cpio curl python3 libarchive pacman-contrib zstd dosfstools >/dev/null
    # синкаем базы под конфиг профиля (там репа EndeavourOS для calamares)
    pacman -Sy --config /work/arch-profile/pacman.conf >/dev/null
    ./build.sh arch
    chown -R --reference=/work/build.sh /work/build
  '

echo ""
echo "=== ГОТОВО ==="
ls -lh build/arch-out/*.iso
