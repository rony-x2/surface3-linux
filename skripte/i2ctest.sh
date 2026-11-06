#!/bin/bash
# i2ctest.sh N DAUER: N parallele Leser fuer DAUER Sekunden, danach Zustand pruefen
N=${1:-2}; D=${2:-60}
a=$(dmesg | grep -c 'controller timed out')
end=$(( $(date +%s) + D ))
for i in $(seq 1 $N); do ( while [ $(date +%s) -lt $end ]; do cat /sys/class/power_supply/BAT0/uevent /sys/class/power_supply/ADP1/uevent >/dev/null 2>&1; done ) & done
wait; sleep 5
b=$(dmesg | grep -c 'controller timed out')
ok=0; for i in 1 2 3; do cat /sys/class/power_supply/ADP1/online >/dev/null 2>&1 && ok=$((ok+1)); sleep 1; done
pgrep -x mshw0011_adp >/dev/null && t=lebt || t=weg
echo "$(date +%T) $(uname -r) N=$N D=$D Timeouts=$((b-a)) ADP1-ok=$ok/3 Polltask=$t" | tee -a /root/i2ctest.log
