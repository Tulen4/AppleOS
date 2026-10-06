#!/bin/bash
# Injects a Ventoy-friendly /boot/grub/grub.cfg into a built AppleOS ISO.
# Ventoy picks this file over its auto-generated menu (which misbuilds our
# entries). Nothing else reads this path, so direct CD/USB boot is unaffected.
# The real ISO uuid is read from the image itself — no rebuild needed.
# Usage: sudo ./scripts/inject-ventoy-grub.sh <appleos.iso>
set -euo pipefail

ISO="${1:?usage: sudo $0 <appleos.iso>}"
[ -f "$ISO" ] || { echo "ERROR: not found: $ISO"; exit 1; }
if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi
command -v xorriso >/dev/null || { echo "ERROR: no xorriso"; exit 1; }
cd "$(dirname "$0")/.."

UUID="$(xorriso -indev "$ISO" -find /boot -maxdepth 1 2>/dev/null | grep -oE '[0-9]{4}(-[0-9]{2}){6}' | head -1)"
[ -n "$UUID" ] || { echo "ERROR: uuid not found in $ISO (not an archiso?)"; exit 1; }
echo "[ventoy] iso uuid: $UUID"

# Output next to the ISO (NOT /tmp: tmpfs may be smaller than the image)
OUTDIR="$(dirname "$ISO")"
OUTTMP="$OUTDIR/.ventoy-inject-tmp.iso"
trap 'rm -f "$OUTTMP"; rm -rf "$TMP"' EXIT
TMP="$(mktemp -d)"
sed "s/@APPLEOS_UUID@/$UUID/g" arch-profile/boot/grub/grub.cfg > "$TMP/grub.cfg"
grep -q "$UUID" "$TMP/grub.cfg" || { echo "ERROR: substitution failed"; exit 1; }

echo "[ventoy] injecting /boot/grub/grub.cfg (El Torito + hybrid MBR preserved via replay)..."
xorriso -indev "$ISO" -outdev "$OUTTMP" -boot_image any replay \
  -map "$TMP/grub.cfg" /boot/grub/grub.cfg 2>&1 | tail -2

echo "[ventoy] verifying..."
xorriso -indev "$OUTTMP" -find /boot/grub/grub.cfg 2>&1 | grep -q "grub.cfg'$" \
  || { echo "ERROR: file missing after inject"; exit 1; }
xorriso -indev "$OUTTMP" -report_el_torito 2>&1 | grep -q "El Torito boot img" \
  || { echo "ERROR: El Torito lost!"; exit 1; }
mv "$OUTTMP" "$ISO"
trap - EXIT; rm -f "$OUTTMP"; rm -rf "$TMP"
echo "[ventoy] OK: $ISO is Ventoy-ready"
