#!/bin/bash
# Downloads static BusyBox and assembles build/rootfs + overlay
set -euo pipefail
cd "$(dirname "$0")/.."

BUSYBOX_VER="1.35.0"
BUSYBOX_URL="https://busybox.net/downloads/binaries/${BUSYBOX_VER}-x86_64-linux-musl/busybox"
ROOTFS="build/rootfs"

mkdir -p "$ROOTFS"/{bin,sbin,etc,proc,sys,dev,tmp,mnt,root,boot,usr/bin,usr/sbin,var} build

if [ ! -f "build/busybox" ]; then
  echo "[rootfs] downloading static busybox $BUSYBOX_VER ..."
  if command -v curl >/dev/null; then
    curl -L -o build/busybox "$BUSYBOX_URL"
  else
    wget -O build/busybox "$BUSYBOX_URL"
  fi
  chmod +x build/busybox
else
  echo "[rootfs] build/busybox already cached, skip download."
fi

echo "[rootfs] installing busybox to $ROOTFS ..."
cp build/busybox "$ROOTFS/bin/busybox"
chmod +x "$ROOTFS/bin/busybox"

# Symlinks for the main applets (the rest is done by `busybox --install -s` inside the OS)
for app in sh ash mount umount echo ls cat ps dmesg uname hostname clear vi mkdir mknod switches; do
  : # placeholder, real links below
done
# Generate links from --list so we get the full command set
"$ROOTFS/bin/busybox" --list 2>/dev/null | while read -r applet; do
  # skip linuxrc/init, our /init plays that role
  case "$applet" in linuxrc|init) continue;; esac
  ln -sf /bin/busybox "$ROOTFS/bin/$applet" 2>/dev/null || true
done
ln -sf /bin/busybox "$ROOTFS/sbin/init" 2>/dev/null || true
mkdir -p "$ROOTFS/usr/bin" "$ROOTFS/usr/sbin"
# Duplicate links into /usr/bin for PATH compatibility
for f in "$ROOTFS"/bin/*; do
  base="$(basename "$f")"
  [ "$base" = "busybox" ] && continue
  ln -sf "/bin/$base" "$ROOTFS/usr/bin/$base" 2>/dev/null || true
done

echo "[rootfs] applying overlay rootfs-overlay/ -> $ROOTFS ..."
cp -a rootfs-overlay/. "$ROOTFS/"
chmod +x "$ROOTFS/init"

# /etc/os-release — the face of the distro (AppleOS is Arch-based)
cat > "$ROOTFS/etc/os-release" <<'EOF'
NAME="AppleOS"
PRETTY_NAME="AppleOS 0.4.0 (minimal, Arch-compatible)"
ID=appleos
ID_LIKE=arch
BASE=arch
VERSION_ID="0.4.0"
VERSION="0.4.0"
BUILD_ID="busybox-static"
HOME_URL="https://example.invalid/appleos"
SUPPORT_URL="https://wiki.archlinux.org/"
BUG_REPORT_URL="https://example.invalid/appleos/bugs"
LOGO=appleos-logo
EOF

# Logo into the system (for neofetch / about)
mkdir -p "$ROOTFS/usr/share/pixmaps"
cp logo.png "$ROOTFS/usr/share/pixmaps/appleos-logo.png" 2>/dev/null || true

echo "[rootfs] OK: $(du -sh "$ROOTFS" | cut -f1) , $(ls "$ROOTFS/bin" | wc -l) applets"
