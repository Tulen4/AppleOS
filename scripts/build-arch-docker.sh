#!/bin/bash
# Build the Arch-based AppleOS ISO inside a Docker container with clean Arch.
# Works on ANY Linux distro — only Docker is needed.
# Usage: ./scripts/build-arch-docker.sh
# Output: build/arch-out/*.iso (ownership returned to the project owner).
set -euo pipefail
cd "$(dirname "$0")/.."

command -v docker >/dev/null || {
  echo "ERROR: no docker."
  echo "  Arch:   sudo pacman -S docker && sudo systemctl enable --now docker"
  echo "  Ubuntu: sudo apt install docker.io && sudo systemctl enable --now docker"
  echo "  Fedora: sudo dnf install docker && sudo systemctl enable --now docker"
  exit 1
}

echo "[docker] building AppleOS arch ISO in archlinux:latest container..."
echo "[docker] (first run pulls ~1 GB image and ~2 GB packages, then cached)"
docker run --rm --privileged \
  -v "$PWD:/work" -w /work \
  archlinux:latest \
  bash -c '
    set -e
    pacman -Sy --noconfirm --needed archiso sudo grub xorriso squashfs-tools \
      cpio curl python3 libarchive pacman-contrib zstd dosfstools >/dev/null
    # sync databases for the profile config (it has the EndeavourOS repo for calamares)
    pacman -Sy --config /work/arch-profile/pacman.conf >/dev/null
    ./build.sh arch
    chown -R --reference=/work/build.sh /work/build
  '

echo ""
echo "=== DONE ==="
ls -lh build/arch-out/*.iso
