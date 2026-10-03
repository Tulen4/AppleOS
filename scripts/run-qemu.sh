#!/bin/bash
# Запуск AppleOS в QEMU. Режимы: ./run-qemu.sh [kernel|iso]  (default: kernel — быстрее)
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-kernel}"
MEM="${MEM:-512M}"
SMP="${SMP:-2}"

if ! command -v qemu-system-x86_64 >/dev/null; then
  echo "ERROR: qemu-system-x86_64 не найден."
  echo "Установи: sudo pacman -S qemu-system-x86"
  exit 1
fi

# Ядро для прямого запуска (-kernel): скачанное при сборке (build/kernel/),
# НЕ ядро хоста — чтобы тест был одинаковым на любом ПК.
KERNEL="${KERNEL:-build/kernel/vmlinuz-linux}"
if [ ! -f "$KERNEL" ]; then
  echo "Сначала ./build.sh all (ядро скачается автоматически)"
  exit 1
fi

case "$MODE" in
  kernel)
    [ -f build/initramfs.cpio.gz ] || { echo "Сначала ./build.sh all"; exit 1; }
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
    [ -n "${ISO:-}" ] || { echo "Сначала ./build.sh all"; exit 1; }
    echo "[qemu] iso boot: $ISO"
    exec qemu-system-x86_64 \
      -cdrom "$ISO" -boot d \
      -m "$MEM" -smp "$SMP" \
      -nographic -no-reboot
    ;;
  *) echo "usage: $0 [kernel|iso]"; exit 1 ;;
esac
