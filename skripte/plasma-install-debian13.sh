#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
set -x
apt-get -o DPkg::Lock::Timeout=600 update
apt-get -o DPkg::Lock::Timeout=600 install -y --no-install-recommends \
  kde-plasma-desktop sddm sddm-theme-breeze kwin-wayland \
  plasma-nm network-manager plasma-pa pipewire-audio wireplumber \
  maliit-keyboard iio-sensor-proxy \
  firefox-esr firefox-esr-l10n-de konsole dolphin kate ark \
  plasma-systemmonitor kinfocenter systemsettings kscreen powerdevil bluedevil \
  breeze-gtk-theme kde-config-gtk-style xdg-desktop-portal-kde \
  fonts-noto-core fonts-noto-color-emoji \
  firmware-sof-signed alsa-ucm-conf \
  htop btop lm-sensors powertop inxi s-tui \
  locales-all
echo "APT-ENDE rc=$?"
# NetworkManager: WLAN bleibt vorerst bei ifupdown (sonst bricht SSH weg)
systemctl set-default graphical.target
echo FERTIG
