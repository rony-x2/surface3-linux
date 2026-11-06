#!/bin/bash
# lasttest.sh DAUER [gpu]: Volllast (4 CPU-Threads, optional GPU-Video) + 2 Akku-Leser, danach Busse pruefen
D=${1:-300}
J() { journalctl -k -b --no-pager | grep -c -e "$1"; }
a=$(J '808622C1:00: controller timed out'); s=$(J 'SPI transfer timed out')
sysbench cpu --threads=4 --time=$D run >/dev/null 2>&1 &
if [ "$2" = gpu ]; then su - "${S3_BENUTZER:-$(id -nu 1000)}" -c "export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 XDG_SESSION_TYPE=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; timeout $D chromium --user-data-dir=/tmp/cr-last --no-first-run file:///home/rony/vtest/index.html >/dev/null 2>&1" & fi
end=$(( $(date +%s) + D ))
for i in 1 2; do ( while [ $(date +%s) -lt $end ]; do cat /sys/class/power_supply/BAT0/uevent /sys/class/power_supply/ADP1/uevent >/dev/null 2>&1; sleep 0.5; done ) & done
wait; sleep 5
b=$(J '808622C1:00: controller timed out'); t=$(J 'SPI transfer timed out')
ok=0; for i in 1 2 3; do timeout 10 cat /sys/class/power_supply/ADP1/online >/dev/null 2>&1 && ok=$((ok+1)); sleep 1; done
echo "$(date +%T) $(uname -r) D=$D ${2:-cpu} I2C-Timeouts=$((b-a)) SPI-Timeouts=$((t-s)) ADP1-ok=$ok/3 Temp=$(($(cat /sys/class/thermal/thermal_zone0/temp)/1000))C" | tee -a /root/lasttest.log
