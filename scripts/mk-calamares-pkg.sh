#!/bin/bash
# Local packages for the AppleOS ISO build:
#  1. calamares repack — our module configs inside the calamares package itself.
#     (mkarchiso copies the overlay BEFORE installing packages, and its pacstrap
#     runs without --overwrite, so overlay files matching package files break
#     the build with "exists in filesystem". Two packages can't own the same
#     files either. Collisions are auto-detected.)
#  2. appleos-live-locales — broad locale list for the LIVE session.
#     (Calamares builds its language list from the locale-gen DB and assumes
#     the locales are compiled; stock Arch images only have C.UTF-8, so the
#     language page is empty and search finds nothing. The package writes
#     /etc/locale.gen in post_install (no owned file -> no conflict with glibc)
#     and compiles it with locale-gen, which runs inside the image during pacstrap.)
# Usage: ./scripts/mk-calamares-pkg.sh <staged-profile-dir>
set -euo pipefail

PROFILE_DIR="${1:?usage: $0 <staged-profile-dir>}"
cd "$(dirname "$0")/.."

PKGDIR="build/calamares-repack"
LPKGDIR="build/locales-pkg"
REPODIR="build/pkg"
AIROOTFS="$PROFILE_DIR/airootfs"

rm -rf "$PKGDIR" "$LPKGDIR" "$REPODIR" 2>/dev/null || sudo rm -rf "$PKGDIR" "$LPKGDIR" "$REPODIR"
mkdir -p "$PKGDIR" "$LPKGDIR" "$REPODIR"

# ---------------------------------------------------------------- 1. calamares
# Upstream package (from cache or download). Take the URL of EXACTLY
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

# Which of our etc/calamares/* files collide with the package?
mapfile -t COLLIDE < <(
  comm -12 \
    <(cd "$AIROOTFS" && find etc/calamares -type f | sort) \
    <(tar -tf "$CALA_PKG" | grep "^etc/calamares/" | grep -v "/$" | sort)
)

REPACKED=""
if [ "${#COLLIDE[@]}" -eq 0 ]; then
  echo "[calamares-pkg] no collisions, using stock calamares."
else
  echo "[calamares-pkg] repacking $(basename "$CALA_PKG") with our versions of:"
  printf '  %s\n' "${COLLIDE[@]}"
  # Unpack upstream, swap configs, remove them from the overlay
  bsdtar -xpf "$CALA_PKG" -C "$PKGDIR"
  GOTPKG="$(grep -m1 "^pkgname = " "$PKGDIR/.PKGINFO" | cut -d= -f2 | tr -d ' ')"
  [ "$GOTPKG" = calamares ] || { echo "ERROR: this is not calamares but '$GOTPKG': $CALA_PKG"; exit 1; }
  for f in "${COLLIDE[@]}"; do
    cp "$AIROOTFS/$f" "$PKGDIR/$f"
    rm "$AIROOTFS/$f"
  done
  rm -f "$PKGDIR/.MTREE"   # checksums are stale after the swap

  # Version +.appleos1: otherwise the filename matches the original in the pacstrap
  # cache (/var/cache/pacman/pkg) and the sha256 check fails as "corrupted".
  # As a bonus, this package is always newer than stock at equal base version.
  ORIGVER="$(grep -m1 "^pkgver = " "$PKGDIR/.PKGINFO" | cut -d= -f2 | tr -d ' ')"
  NEWVER="${ORIGVER}.appleos1"
  CALA_FILE="calamares-${NEWVER}-any.pkg.tar.zst"

  # .PKGINFO: new version, fresh size + backup= for our configs
  grep -v -e "^pkgver = " -e "^size = " -e "^backup = " "$PKGDIR/.PKGINFO" > "$PKGDIR/.PKGINFO.new" || true
  {
    cat "$PKGDIR/.PKGINFO.new"
    echo "pkgver = $NEWVER"
    echo "size = $(du -sb "$PKGDIR" | cut -f1)"
    for f in "${COLLIDE[@]}"; do echo "backup = $f"; done
  } > "$PKGDIR/.PKGINFO"
  rm "$PKGDIR/.PKGINFO.new"

  # Pack (root owner)
  (cd "$PKGDIR" && tar --numeric-owner --owner=0 --group=0 -I 'zstd -19' -cf "$OLDPWD/$REPODIR/$CALA_FILE" .BUILDINFO .PKGINFO etc usr)
  REPACKED="$REPODIR/$CALA_FILE"
  echo "[calamares-pkg] OK: $REPACKED"
fi

# ------------------------------------------------- 2. appleos-live-locales
# Broad locale list, compiled at install time so `locale -a` (and Calamares)
# sees real languages in the live session.
LOCALES_FILE="appleos-live-locales-1.0-1-any.pkg.tar.zst"
mkdir -p "$LPKGDIR/etc"
cat > "$LPKGDIR/.INSTALL" <<'INSTALL_EOF'
#!/bin/sh
post_install() {
    # Locales for the live session: Calamares lists languages from the
    # locale-gen DB and assumes they are compiled. Runs inside the image.
    cat > /etc/locale.gen <<'LOCALES_EOF'
en_US.UTF-8 UTF-8
en_GB.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
uk_UA.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
de_AT.UTF-8 UTF-8
fr_FR.UTF-8 UTF-8
fr_CA.UTF-8 UTF-8
es_ES.UTF-8 UTF-8
es_MX.UTF-8 UTF-8
pt_PT.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
it_IT.UTF-8 UTF-8
nl_NL.UTF-8 UTF-8
nl_BE.UTF-8 UTF-8
pl_PL.UTF-8 UTF-8
cs_CZ.UTF-8 UTF-8
sk_SK.UTF-8 UTF-8
hu_HU.UTF-8 UTF-8
ro_RO.UTF-8 UTF-8
bg_BG.UTF-8 UTF-8
hr_HR.UTF-8 UTF-8
sr_RS.UTF-8 UTF-8
sl_SI.UTF-8 UTF-8
sv_SE.UTF-8 UTF-8
da_DK.UTF-8 UTF-8
fi_FI.UTF-8 UTF-8
nb_NO.UTF-8 UTF-8
nn_NO.UTF-8 UTF-8
et_EE.UTF-8 UTF-8
lv_LV.UTF-8 UTF-8
lt_LT.UTF-8 UTF-8
el_GR.UTF-8 UTF-8
tr_TR.UTF-8 UTF-8
ar_SA.UTF-8 UTF-8
he_IL.UTF-8 UTF-8
fa_IR.UTF-8 UTF-8
hi_IN.UTF-8 UTF-8
th_TH.UTF-8 UTF-8
vi_VN.UTF-8 UTF-8
id_ID.UTF-8 UTF-8
ms_MY.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
zh_HK.UTF-8 UTF-8
ja_JP.UTF-8 UTF-8
ko_KR.UTF-8 UTF-8
ca_ES.UTF-8 UTF-8
eu_ES.UTF-8 UTF-8
gl_ES.UTF-8 UTF-8
LOCALES_EOF
    locale-gen
    # Default plymouth theme (the package default can't be overlayed:
    # plymouth ships its own plymouthd.conf).
    mkdir -p /etc/plymouth
    printf '[Daemon]\nTheme=appleos\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf
}
INSTALL_EOF
{
  echo "pkgname = appleos-live-locales"
  echo "pkgver = 1.0-1"
  echo "pkgdesc = Broad locale set for the AppleOS live session"
  echo "url = https://example.invalid/appleos"
  echo "builddate = $(date +%s)"
  echo "packager = AppleOS Builder"
  echo "size = $(du -sb "$LPKGDIR" | cut -f1)"
  echo "arch = any"
  echo "license = GPL-3.0-only"
} > "$LPKGDIR/.PKGINFO"
(cd "$LPKGDIR" && tar --numeric-owner --owner=0 --group=0 -I 'zstd -19' -cf "$OLDPWD/$REPODIR/$LOCALES_FILE" .INSTALL .PKGINFO etc)
echo "[locales-pkg] OK: $REPODIR/$LOCALES_FILE ($(grep -c UTF-8 "$LPKGDIR/.INSTALL") locales)"

# --------------------------------- 2.5 offline installer tree (for -c <dir>)
# calamares -c takes a DIRECTORY with a full config tree (settings.conf + qml/
# + modules/ + branding/...), NOT a file. Build offline/ from the extracted
# package tree + our overrides.
OFF="$AIROOTFS/etc/calamares/offline"
rm -rf "$OFF"
mkdir -p "$OFF"
[ -f "$PKGDIR/.PKGINFO" ] || bsdtar -xpf "$CALA_PKG" -C "$PKGDIR"
cp -a "$PKGDIR/etc/calamares/modules" "$PKGDIR/etc/calamares/qml" \
      "$PKGDIR/etc/calamares/scripts" "$PKGDIR/etc/calamares/files" \
      "$PKGDIR/etc/calamares/de_images" "$PKGDIR/etc/calamares/calamares-translations.txt" "$OFF/" 2>/dev/null || true
mkdir -p "$OFF/branding"
# NOTE: our confs from SOURCE (repack step may have moved them out of staged overlay)
cp -a arch-profile/airootfs/etc/calamares/branding/appleos "$OFF/branding/"
cp -a arch-profile/airootfs/etc/calamares/modules/. "$OFF/modules/"
cp arch-profile/calamares-offline-settings.conf "$OFF/settings.conf"
echo "[offline] tree ready: $(find "$OFF" -type f | wc -l) files, no netinstall:" \
  "$(grep -c netinstall "$OFF/settings.conf" || true)"

# ------------------------------------------------- 3. local repository
repo-add "$REPODIR/appleos-local.db.tar.gz" "$REPODIR"/appleos-live-locales-*.pkg.tar.zst ${REPACKED:+$REPACKED} >/dev/null

# Local repository FIRST in the staged pacman.conf (wins ties at equal version)
REPODIR_ABS="$(realpath "$REPODIR")"
REPO_SECT="# --- AppleOS: local repository (repacked calamares + live locales) ---
[appleos-local]
SigLevel = Never
Server = file://$REPODIR_ABS
"
{
  echo "$REPO_SECT"
  cat "$PROFILE_DIR/pacman.conf"
} > "$PROFILE_DIR/pacman.conf.new"
mv "$PROFILE_DIR/pacman.conf.new" "$PROFILE_DIR/pacman.conf"

echo "appleos-live-locales" >> "$PROFILE_DIR/packages.x86_64"

echo "[local-pkgs] repo ready: $REPODIR"
