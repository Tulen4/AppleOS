#!/bin/bash
# Dependency check for the AppleOS minimal build (rootless, any distro).
# Usage: ./scripts/check-deps.sh
# Returns 0 if everything is present, else prints what to install and exits 1.
set -u

MISSING=()

need() { command -v "$1" >/dev/null 2>&1 || MISSING+=("$1"); }

need curl
need cpio
need gzip
need grub-mkrescue
need xorriso
need python3
# for unpacking the kernel .pkg.tar.zst: bsdtar OR (tar + zstd)
if ! command -v bsdtar >/dev/null 2>&1; then
  command -v zstd >/dev/null 2>&1 || MISSING+=("bsdtar|zstd")
fi

if [ "${#MISSING[@]}" -eq 0 ]; then
  echo "[deps] OK: all minimal-build dependencies present."
  exit 0
fi

echo "[deps] MISSING: ${MISSING[*]}"
echo ""
echo "Install with one command for your distro:"
echo "  Arch/EndeavourOS: sudo pacman -S --needed curl cpio grub xorriso python libarchive zstd"
echo "  Debian/Ubuntu:    sudo apt install curl cpio grub-common grub-pc-bin xorriso python3 libarchive-tools zstd"
echo "  Fedora:           sudo dnf install curl cpio grub2-tools xorriso python3 bsdtar zstd"
exit 1
