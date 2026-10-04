#!/bin/bash
# Repacks the calamares package, replacing its default configs with ours.
# Why: mkarchiso copies the overlay BEFORE installing packages, and its pacstrap
# runs without --overwrite, so overlay files matching package files break
# the build ("exists in filesystem"). And two packages can't own the same
# files either — so our configs must travel INSIDE the calamares package.
# Collisions are auto-detected.
# Usage: ./scripts/mk-calamares-pkg.sh <staged-profile-dir>
set -euo pipefail

PROFILE_DIR="${1:?usage: $0 <staged-profile-dir>}"
cd "$(dirname "$0")/.."

PKGDIR="build/calamares-repack"
REPODIR="build/pkg"
AIROOTFS="$PROFILE_DIR/airootfs"

rm -rf "$PKGDIR" "$REPODIR" 2>/dev/null || sudo rm -rf "$PKGDIR" "$REPODIR"
mkdir -p "$PKGDIR" "$REPODIR"

# 1. Upstream calamares package (from cache or download). Take the URL of EXACTLY
# the 'calamares' package: pacman -Sp also prints dependencies, tail -1 is unreliable.
# PACMAN_CONFIG (from build-arch-iso.sh) points at the profile config with the EndeavourOS repo.
SP_ARGS=()
[ -n "${PACMAN_CONFIG:-}" ] && SP_ARGS=(--config "$PACMAN_CONFIG")
CALA_URL="$(pacman -Sp "${SP_ARGS[@]}" --print-format '%n %l' calamares 2>/dev/null | awk '$1=="calamares" {print $2; exit}')"
[ -n "$CALA_URL" ] || { echo "ERROR: pacman doesn't know calamares (needs the EndeavourOS repo, or build via docker: ./scripts/build-arch-docker.sh)"; exit 1; }
if [[ "$CALA_URL" == file://* ]]; then
  CALA_PKG="${CALA_URL#file://}"
  tar -tf "$CALA_PKG" >/dev/null 2>&1 || { echo "ERROR: broken package in cache: $CALA_PKG"; exit 1; }
else
  echo "[calamares-pkg] downloading calamares package..."
  mkdir -p build/upstream
  CALA_PKG="build/upstream/$(basename "$CALA_URL")"
  # Partial file after a dropped connection — download again
  if [ -f "$CALA_PKG" ] && ! tar -tf "$CALA_PKG" >/dev/null 2>&1; then
    echo "[calamares-pkg] cached file broken, re-downloading..."
    rm -f "$CALA_PKG" 2>/dev/null || sudo rm -f "$CALA_PKG"
  fi
  [ -f "$CALA_PKG" ] || curl --retry 3 --retry-all-errors -L -o "$CALA_PKG" "$CALA_URL"
  tar -tf "$CALA_PKG" >/dev/null 2>&1 || { echo "ERROR: downloaded package is broken: $CALA_PKG"; exit 1; }
fi

# 2. Which of our etc/calamares/* files collide with the package?
mapfile -t COLLIDE < <(
  comm -12 \
    <(cd "$AIROOTFS" && find etc/calamares -type f | sort) \
    <(tar -tf "$CALA_PKG" | grep "^etc/calamares/" | grep -v "/$" | sort)
)
[ "${#COLLIDE[@]}" -gt 0 ] || { echo "[calamares-pkg] no collisions, using stock calamares."; exit 0; }
echo "[calamares-pkg] repacking $(basename "$CALA_PKG") with our versions of:"
printf '  %s\n' "${COLLIDE[@]}"

# 3. Unpack upstream, swap configs, remove them from the overlay
bsdtar -xpf "$CALA_PKG" -C "$PKGDIR"
GOTPKG="$(grep -m1 "^pkgname = " "$PKGDIR/.PKGINFO" | cut -d= -f2 | tr -d ' ')"
[ "$GOTPKG" = calamares ] || { echo "ERROR: this is not calamares but '$GOTPKG': $CALA_PKG"; exit 1; }
for f in "${COLLIDE[@]}"; do
  cp "$AIROOTFS/$f" "$PKGDIR/$f"
  rm "$AIROOTFS/$f"
done
rm -f "$PKGDIR/.MTREE"   # checksums are stale after the swap

# 4. Version +.appleos1: otherwise the filename matches the original in the pacstrap
# cache (/var/cache/pacman/pkg) and the sha256 check fails as "corrupted".
# As a bonus, this package is always newer than stock at equal base version.
ORIGVER="$(grep -m1 "^pkgver = " "$PKGDIR/.PKGINFO" | cut -d= -f2 | tr -d ' ')"
NEWVER="${ORIGVER}.appleos1"
CALA_FILE="calamares-${NEWVER}-any.pkg.tar.zst"

# 5. .PKGINFO: new version, fresh size + backup= for our configs
grep -v -e "^pkgver = " -e "^size = " -e "^backup = " "$PKGDIR/.PKGINFO" > "$PKGDIR/.PKGINFO.new" || true
{
  cat "$PKGDIR/.PKGINFO.new"
  echo "pkgver = $NEWVER"
  echo "size = $(du -sb "$PKGDIR" | cut -f1)"
  for f in "${COLLIDE[@]}"; do echo "backup = $f"; done
} > "$PKGDIR/.PKGINFO"
rm "$PKGDIR/.PKGINFO.new"

# 6. Pack (root owner) and local repository
(cd "$PKGDIR" && tar --numeric-owner --owner=0 --group=0 -I 'zstd -19' -cf "$OLDPWD/$REPODIR/$CALA_FILE" .BUILDINFO .PKGINFO etc usr)
repo-add "$REPODIR/appleos-local.db.tar.gz" "$REPODIR/$CALA_FILE" >/dev/null

# 7. Local repository FIRST in the staged pacman.conf (wins ties at equal version)
REPODIR_ABS="$(realpath "$REPODIR")"
REPO_SECT="# --- AppleOS: local repository (repacked calamares) ---
[appleos-local]
SigLevel = Never
Server = file://$REPODIR_ABS
"
{
  echo "$REPO_SECT"
  cat "$PROFILE_DIR/pacman.conf"
} > "$PROFILE_DIR/pacman.conf.new"
mv "$PROFILE_DIR/pacman.conf.new" "$PROFILE_DIR/pacman.conf"

echo "[calamares-pkg] OK: $REPODIR/$CALA_FILE"
