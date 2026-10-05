#!/usr/bin/env bash
# shellcheck disable=SC2034
# AppleOS — Arch-based. archiso profile based on releng.

iso_name="appleos"
iso_label="APPLEOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="AppleOS <https://example.invalid/appleos>"
iso_application="AppleOS Live/Rescue (based on Arch Linux)"
iso_version="0.3.0"
install_dir="appleos"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/etc/sudoers.d/10-liveuser"]="0:0:440"
  ["/usr/local/bin/appleos-drivers"]="0:0:755"
  ["/usr/local/bin/appleos-finish"]="0:0:755"
  ["/usr/local/bin/appleos-live"]="0:0:755"
  ["/usr/local/bin/appleos-wifi"]="0:0:755"
  ["/usr/local/bin/appleos-installer-chooser"]="0:0:755"
  ["/usr/local/bin/appleos-welcome"]="0:0:755"
)
