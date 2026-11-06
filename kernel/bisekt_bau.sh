#!/bin/bash
# Bisektions-Bau: Vanilla-Kernel (ohne linux-surface) aus ~/kernelbau/linux-git, schlanke Konfiguration
# Aufruf: ./bisekt_bau.sh <Kennung>   (Ergebnis: ~/kernelbau/bisekt/*.deb)
set -euo pipefail
k=${1:?Kennung fehlt}
cd ~/kernelbau/linux-git
git clean -fdxq -e .config >/dev/null 2>&1 || true
cp ../s3_config.txt .config
make olddefconfig >/dev/null
cp ../s3_lsmod618.txt /tmp/bis_lsmod
for m in usb_storage uas vfat exfat r8152 asix cdc_ether btusb uinput fuse loop hid_multitouch; do echo "$m 0 0" >> /tmp/bis_lsmod; done
make LSMOD=/tmp/bis_lsmod localmodconfig < /dev/null >/dev/null 2>&1 || true
scripts/config --set-str LOCALVERSION "-bis$k" --disable LOCALVERSION_AUTO \
  --disable DEBUG_INFO --disable DEBUG_INFO_DWARF5 --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT --disable DEBUG_INFO_BTF --enable DEBUG_INFO_NONE \
  --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" --set-str MODULE_SIG_KEY "certs/signing_key.pem" \
  --module DRM_I915 --set-val NR_CPUS 4
if [ -n "${EXTRA:-}" ]; then scripts/config $EXTRA; fi
make olddefconfig >/dev/null
echo "Stand: $(git describe --tags) Module: $(grep -c '=m$' .config)"
mkdir -p ../bisekt
time make -j7 LOCALVERSION= bindeb-pkg >../bisekt/bau-$k.log 2>&1
mv ../linux-image-*-bis${k}_*.deb ../linux-headers-*-bis${k}_*.deb ../bisekt/ 2>/dev/null || mv ../linux-image-*bis${k}*.deb ../linux-headers-*bis${k}*.deb ../bisekt/
rm -f ../linux-libc-dev_*.deb ../*.buildinfo ../*.changes
ls ../bisekt/*bis${k}*.deb
echo BAU-FERTIG