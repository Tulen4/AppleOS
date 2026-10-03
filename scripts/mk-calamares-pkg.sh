#!/bin/bash
# Перепаковывает пакет calamares, подменяя его дефолтные конфиги нашими.
# Зачем: mkarchiso копирует overlay ДО установки пакетов, а его pacstrap
# вызывается без --overwrite, поэтому файлы overlay, совпадающие с файлами
# пакета, роняют сборку ("exists in filesystem"). А два пакета владеть
# одними файлами тоже не могут — значит наши конфиги должны ехать ВНУТРИ
# пакета calamares. Коллизии детектятся автоматически.
# Использование: ./scripts/mk-calamares-pkg.sh <staged-profile-dir>
set -euo pipefail

PROFILE_DIR="${1:?usage: $0 <staged-profile-dir>}"
cd "$(dirname "$0")/.."

PKGDIR="build/calamares-repack"
REPODIR="build/pkg"
AIROOTFS="$PROFILE_DIR/airootfs"

rm -rf "$PKGDIR" "$REPODIR" 2>/dev/null || sudo rm -rf "$PKGDIR" "$REPODIR"
mkdir -p "$PKGDIR" "$REPODIR"

# 1. Оригинальный пакет calamares (из кэша или скачать). Берем URL ТОЧНО пакета
# 'calamares': pacman -Sp выводит еще и зависимости, tail -1 там ненадежен.
# PACMAN_CONFIG (из build-arch-iso.sh) указывает на конфиг профиля с репой EndeavourOS.
SP_ARGS=()
[ -n "${PACMAN_CONFIG:-}" ] && SP_ARGS=(--config "$PACMAN_CONFIG")
CALA_URL="$(pacman -Sp "${SP_ARGS[@]}" --print-format '%n %l' calamares 2>/dev/null | awk '$1=="calamares" {print $2; exit}')"
[ -n "$CALA_URL" ] || { echo "ERROR: pacman не знает calamares (нужен репозиторий EndeavourOS или сборка через docker: ./scripts/build-arch-docker.sh)"; exit 1; }
if [[ "$CALA_URL" == file://* ]]; then
  CALA_PKG="${CALA_URL#file://}"
  tar -tf "$CALA_PKG" >/dev/null 2>&1 || { echo "ERROR: битый пакет в кэше: $CALA_PKG"; exit 1; }
else
  echo "[calamares-pkg] downloading calamares package..."
  mkdir -p build/upstream
  CALA_PKG="build/upstream/$(basename "$CALA_URL")"
  # Недокачанный файл после обрыва соединения — качаем заново
  if [ -f "$CALA_PKG" ] && ! tar -tf "$CALA_PKG" >/dev/null 2>&1; then
    echo "[calamares-pkg] cached file broken, re-downloading..."
    rm -f "$CALA_PKG" 2>/dev/null || sudo rm -f "$CALA_PKG"
  fi
  [ -f "$CALA_PKG" ] || curl --retry 3 --retry-all-errors -L -o "$CALA_PKG" "$CALA_URL"
  tar -tf "$CALA_PKG" >/dev/null 2>&1 || { echo "ERROR: скачанный пакет битый: $CALA_PKG"; exit 1; }
fi

# 2. Какие наши файлы etc/calamares/* пересекаются с пакетом?
mapfile -t COLLIDE < <(
  comm -12 \
    <(cd "$AIROOTFS" && find etc/calamares -type f | sort) \
    <(tar -tf "$CALA_PKG" | grep "^etc/calamares/" | grep -v "/$" | sort)
)
[ "${#COLLIDE[@]}" -gt 0 ] || { echo "[calamares-pkg] no collisions, using stock calamares."; exit 0; }
echo "[calamares-pkg] repacking $(basename "$CALA_PKG") with our versions of:"
printf '  %s\n' "${COLLIDE[@]}"

# 3. Распаковка оригинала, подмена конфигов, удаление из overlay
bsdtar -xpf "$CALA_PKG" -C "$PKGDIR"
GOTPKG="$(grep -m1 "^pkgname = " "$PKGDIR/.PKGINFO" | cut -d= -f2 | tr -d ' ')"
[ "$GOTPKG" = calamares ] || { echo "ERROR: это не calamares, а '$GOTPKG': $CALA_PKG"; exit 1; }
for f in "${COLLIDE[@]}"; do
  cp "$AIROOTFS/$f" "$PKGDIR/$f"
  rm "$AIROOTFS/$f"
done
rm -f "$PKGDIR/.MTREE"   # контрольные суммы устарели после подмены

# 4. Версия +.appleos1: иначе имя файла совпадет с оригиналом в кэше pacstrap
# (/var/cache/pacman/pkg) и проверка sha256 упадет как "corrupted".
# Заодно такой пакет всегда новее стокового при равной базовой версии.
ORIGVER="$(grep -m1 "^pkgver = " "$PKGDIR/.PKGINFO" | cut -d= -f2 | tr -d ' ')"
NEWVER="${ORIGVER}.appleos1"
CALA_FILE="calamares-${NEWVER}-any.pkg.tar.zst"

# 5. .PKGINFO: новая версия, свежий размер + backup= на наши конфиги
grep -v -e "^pkgver = " -e "^size = " -e "^backup = " "$PKGDIR/.PKGINFO" > "$PKGDIR/.PKGINFO.new" || true
{
  cat "$PKGDIR/.PKGINFO.new"
  echo "pkgver = $NEWVER"
  echo "size = $(du -sb "$PKGDIR" | cut -f1)"
  for f in "${COLLIDE[@]}"; do echo "backup = $f"; done
} > "$PKGDIR/.PKGINFO"
rm "$PKGDIR/.PKGINFO.new"

# 6. Упаковка (владелец root) и локальный репозиторий
(cd "$PKGDIR" && tar --numeric-owner --owner=0 --group=0 -I 'zstd -19' -cf "$OLDPWD/$REPODIR/$CALA_FILE" .BUILDINFO .PKGINFO etc usr)
repo-add "$REPODIR/appleos-local.db.tar.gz" "$REPODIR/$CALA_FILE" >/dev/null

# 7. Локальный репозиторий ПЕРВЫМ в staged pacman.conf (при равной версии побеждает он)
REPODIR_ABS="$(realpath "$REPODIR")"
REPO_SECT="# --- AppleOS: локальный репозиторий (перепакованный calamares) ---
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
