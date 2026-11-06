#!/bin/bash
# Surface 3 (Atom x7-Z8700, Cherry Trail) unter Debian testing (forky) mit KDE Plasma (Wayland) einrichten.
# Mehrfach ausfuehrbar. Aufruf als root aus dem Repo-Ordner:
#   sudo ./einrichten.sh            Systemdateien, Pakete, Einstellungen
#   sudo ./einrichten.sh --i965     zusaetzlich den VA-API-Treiber mit Patch bauen (fuer Chromium-Hardware-Video)
#
# Set up a Surface 3 running Debian testing with KDE Plasma (Wayland). Safe to run repeatedly.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
[ "$(id -u)" -eq 0 ] || { echo "Bitte als root ausfuehren (sudo)."; exit 1; }
BENUTZER=${S3_BENUTZER:-$(id -nu 1000 2>/dev/null || true)}
export DEBIAN_FRONTEND=noninteractive
APT="apt-get -y -o DPkg::Lock::Timeout=300"

echo "== Pakete"
$APT install --no-install-recommends plasma-keyboard iio-sensor-proxy chromium chromium-l10n \
  i965-va-driver vainfo intel-gpu-tools firmware-intel-sound sysbench rt-tests >/dev/null

echo "== Systemdateien"
( cd system && find . -type f ) | while read -r f; do
  ziel="/${f#./}"; install -D -m "$(case "$ziel" in /usr/local/bin/*) echo 755;; *) echo 644;; esac)" "system/$f" "$ziel"
  echo "   $ziel"
done
udevadm control --reload
udevadm trigger -s iio -c add || true
for d in 808622C1:00 8086228E:00 INTL9C60:00 INTL9C60:01; do
  [ -e /sys/bus/platform/devices/$d/power/control ] && echo on > /sys/bus/platform/devices/$d/power/control
done
systemctl daemon-reload
systemctl enable --now lpss-waechter.service >/dev/null 2>&1 || true
systemctl restart iio-sensor-proxy.service || true

echo "== Kernel-Parameter"
P="intel_idle.max_cstate=1 i915.enable_psr=0 button.lid_init_state=open"
if ! grep -q 'button.lid_init_state=open' /etc/default/grub; then
  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $P\"|" /etc/default/grub
  update-grub
fi

echo "== Standby aus (WLAN-Chip mwifiex wacht sonst nicht zuverlaessig auf)"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target >/dev/null

echo "== Benutzereinstellungen fuer ${BENUTZER:-?}"
if [ -n "$BENUTZER" ]; then
  su - "$BENUTZER" -c '
    kwriteconfig6 --file kwinrc --group Wayland --key InputMethod /usr/share/applications/org.kde.plasma.keyboard.desktop
    kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled true
    kwriteconfig6 --file plasmakeyboardrc --group General --key enabledLocales "de_DE,en_US"
    kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction 0
    kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key LidAction 0
  ' || true
fi

if [ "${1:-}" = "--i965" ]; then
  echo "== i965-VA-API-Treiber mit Patch bauen"
  $APT install dpkg-dev build-essential devscripts >/dev/null
  $APT build-dep intel-vaapi-driver >/dev/null
  w=$(mktemp -d); p=$(readlink -f patches/i965/0001-allocate-bo-on-export.patch)
  ( cd "$w" && apt-get source intel-vaapi-driver >/dev/null 2>&1 && cd intel-vaapi-driver-*/ \
    && patch -p1 -s < "$p" \
    && DEBFULLNAME="surface3-linux" DEBEMAIL="root@localhost" dch --local +surface3 "Allocate surface bo on vaExportSurfaceHandle()." \
    && DEB_BUILD_OPTIONS="parallel=$(nproc) nocheck" DEB_CFLAGS_APPEND="-march=silvermont -mtune=silvermont" dpkg-buildpackage -b -uc -us >/dev/null )
  dpkg -i "$w"/i965-va-driver_*surface3*_amd64.deb
  apt-mark hold i965-va-driver
  echo "   Treiber gebaut, installiert und auf hold gesetzt (Bauordner: $w)"
fi

echo "== Fertig. Neustart empfohlen."
