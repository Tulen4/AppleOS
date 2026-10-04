EN
# AppleOS

Arch-based Linux distro with COSMIC desktop, Calamares GUI installer
(online + offline modes), Wi-Fi from the live session, and driver autodetect.
Built with [Muse Spark](https://opencode.ai) `muse-spark-1.3 free`.

```bash
./build.sh            # auto: native ISO on Arch, Docker ISO elsewhere, minimal otherwise
./build.sh arch       # full live ISO with installer (Arch, sudo)
./build.sh all        # minimal BusyBox ISO, rootless
./scripts/run-qemu.sh # test the ISO in QEMU
```

EN docs live in the scripts (`build.sh`, `scripts/`). Sources: `arch-profile/` (live system),
`rootfs-overlay/` (minimal init), `grub/`, `logo.png` + `fastfetch.txt` (branding).

---

RU
# AppleOS

Arch-based дистрибутив с COSMIC, GUI-установщиком Calamares
(онлайн + офлайн режимы), Wi-Fi из live-сессии и автоустановкой драйверов.

```bash
./build.sh            # авто: на Arch — полный ISO, на другом дистре — через Docker, иначе minimal
./build.sh arch       # полный live ISO с установщиком (Arch, sudo)
./build.sh all        # минимальный BusyBox ISO, без root
./scripts/run-qemu.sh # тест ISO в QEMU
```

Исходники: `arch-profile/` (live-система), `rootfs-overlay/` (minimal init),
`grub/`, `logo.png` + `fastfetch.txt` (брендинг).
