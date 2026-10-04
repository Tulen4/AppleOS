#!/bin/bash
# Run AppleOS in QEMU. Modes: ./run-qemu.sh [kernel|iso]  (default: kernel — faster)
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-kernel}"
MEM="${MEM:-512M}"
SMP="${SMP:-2}"

if ! command -v qemu-system-x86_64 >/dev/null; then
  echo "ERROR: qemu-system-x86_64 not found."
  echo "  Arch:   sudo pacman -S qemu-system-x86"
  echo "  Ubuntu: sudo apt install qemu-system-x86"
  echo "  Fedora: sudo dnf install qemu-system-x86"
  exit 1
fi

# Kernel for direct boot (-kernel): downloaded at build time (build/kernel/),
# NOT the host kernel — so the test is identical on any PC.
KERNEL="${KERNEL:-build/kernel/vmlinuz-linux}"
if [ ! -f "$KERNEL" ]; then
  echo "Run ./build.sh all first (the kernel downloads automatically)"
  exit 1
fi

case "$MODE" in
  kernel)
    [ -f build/initramfs.cpio.gz ] || { echo "Run ./build.sh all first"; exit 1; }
    echo "[qemu] direct kernel boot: $KERNEL"
    exec qemu-system-x86_64 \
      -kernel "$KERNEL" \
      -initrd build/initramfs.cpio.gz \
      -append "console=ttyS0,115200 console=tty0 init=/init panic=1" \
      -m "$MEM" -smp "$SMP" \
      -nographic -no-reboot
    ;;
  iso)
    ISO="$(ls -t build/appleos-*.iso 2>/dev/null | head -1)"
    [ -n "${ISO:-}" ] || { echo "Run ./build.sh all first"; exit 1; }
    echo "[qemu] iso boot: $ISO"
    exec qemu-system-x86_64 \
      -cdrom "$ISO" -boot d \
      -m "$MEM" -smp "$SMP" \
      -nographic -no-reboot
    ;;
  *) echo "usage: $0 [kernel|iso]"; exit 1 ;;
esac
