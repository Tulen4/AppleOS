#!/bin/bash
# Проверка зависимостей для minimal-сборки AppleOS (без root, на любом дистрибутиве).
# Использование: ./scripts/check-deps.sh
# Возвращает 0 если все есть, иначе печатает что доставить и выходит 1.
set -u

MISSING=()

need() { command -v "$1" >/dev/null 2>&1 || MISSING+=("$1"); }

need curl
need cpio
need gzip
need grub-mkrescue
need xorriso
need python3
# чем распаковывать .pkg.tar.zst с ядром: bsdtar ИЛИ (tar + zstd)
if ! command -v bsdtar >/dev/null 2>&1; then
  command -v zstd >/dev/null 2>&1 || MISSING+=("bsdtar|zstd")
fi

if [ "${#MISSING[@]}" -eq 0 ]; then
  echo "[deps] OK: все зависимости minimal-сборки на месте."
  exit 0
fi

echo "[deps] НЕ ХВАТАЕТ: ${MISSING[*]}"
echo ""
echo "Доставь одной командой под свой дистрибутив:"
echo "  Arch/EndeavourOS: sudo pacman -S --needed curl cpio grub xorriso python libarchive zstd"
echo "  Debian/Ubuntu:    sudo apt install curl cpio grub-common grub-pc-bin xorriso python3 libarchive-tools zstd"
echo "  Fedora:           sudo dnf install curl cpio grub2-tools xorriso python3 bsdtar zstd"
exit 1
