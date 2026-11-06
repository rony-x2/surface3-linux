#!/bin/bash
# Surface 3: Debian 13 (trixie) -> testing (forky)
set -e
mkdir -p /root/vor-forky
tar czf /root/vor-forky/etc.tgz /etc 2>/dev/null
dpkg --get-selections > /root/vor-forky/pakete.txt
cp /etc/apt/sources.list /root/vor-forky/sources.list
export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none
O="-o DPkg::Lock::Timeout=300 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
echo "== trixie aktualisieren"; apt-get $O update; apt-get $O -y full-upgrade
echo "== Quellen auf forky"; sed -i 's/trixie/forky/g' /etc/apt/sources.list
apt-get $O update || { echo "forky-updates fehlt, entferne"; sed -i '/forky-updates/d' /etc/apt/sources.list; apt-get $O update; }
echo "== Teil-Upgrade"; apt-get $O -y upgrade --without-new-pkgs
echo "== Voll-Upgrade"; apt-get $O -y full-upgrade
echo "== Ueberzaehlige Pakete (nur Liste)"; apt-get -s autoremove | grep '^Remv' || true
echo UPGRADE-FERTIG
