#!/bin/bash
# Kernel 7.3.3 + linux-surface fuer Surface 3 (Atom x7-Z8700, Airmont), Bau auf der lm-vm
set -euo pipefail
cd ~/kernelbau
grep ' linux-7.3.3.tar.xz' sha256sums.asc | sha256sum -c -
rm -rf linux-7.3.3 && tar xf linux-7.3.3.tar.xz && cd linux-7.3.3
for p in ../linux-surface/patches/7.3/*.patch; do echo "Patch $(basename $p)"; patch -p1 -s < "$p"; done
for p in ../eigene-patches/*.patch; do echo "Eigener Patch $(basename $p)"; patch -p1 -s < "$p"; done
# Basis: Debian-Konfiguration des Surface 3
cp ../s3_config.txt .config
make olddefconfig >/dev/null
# Nur benoetigte Module (aktuell geladen + Extras fuer USB-Sticks, LAN-Adapter, NAS, Bluetooth usw.)
cp ../s3_lsmod.txt /tmp/s3_lsmod
for m in usb_storage uas vfat fat exfat ntfs3 isofs udf r8152 asix ax88179_178a cdc_ether usbnet cdc_ncm btusb btmrvl btmrvl_sdio bluetooth rfcomm bnep uinput fuse zram loop snd_usb_audio uvcvideo hid_multitouch joydev wireguard tun cifs nfs nfsv4 btrfs xfs squashfs overlay dm_crypt hid_logitech_dj hid_logitech_hidpp usbhid; do echo "$m 0 0" >> /tmp/s3_lsmod; done
true # v2: volle Debian-Konfiguration, keine Modul-Ausduennung
# linux-surface-Optionen und eigene Einstellungen
scripts/kconfig/merge_config.sh -m .config ../linux-surface/configs/surface-7.3.config >/dev/null
scripts/config \
  --set-str LOCALVERSION "-surface3b" --disable LOCALVERSION_AUTO \
  --enable PREEMPT --disable PREEMPT_VOLUNTARY --disable PREEMPT_NONE --enable PREEMPT_DYNAMIC \
  --enable HZ_1000 --disable HZ_250 --set-val HZ 1000 \
  --enable NO_HZ_IDLE \
  --disable DEBUG_INFO --disable DEBUG_INFO_DWARF5 --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT --disable DEBUG_INFO_BTF --enable DEBUG_INFO_NONE \
  --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" \
  --enable MODULE_SIG --enable MODULE_SIG_ALL --enable MODULE_SIG_SHA512 --set-str MODULE_SIG_KEY "certs/signing_key.pem" \
  --module DRM_I915 \
  --set-val NR_CPUS 4 \
  --disable X86_NATIVE_CPU
make olddefconfig >/dev/null
echo "Module: $(grep -c '=m$' .config)  eingebaut: $(grep -c '=y$' .config)"
grep -E '^CONFIG_(PREEMPT|HZ|DRM_I915|SURFACE_3|SURFACE3|MWIFIEX|HID_SENSOR_HUB)[A-Z_0-9]*=' .config | tr '\n' ' '; echo
# Uebersetzen fuer Airmont (Silvermont-Befehlssatz)
time make -j7 KCFLAGS="-march=silvermont -mtune=silvermont -O2" LOCALVERSION= bindeb-pkg >../bau.log 2>&1
ls -la ../*.deb
echo BAU-FERTIG