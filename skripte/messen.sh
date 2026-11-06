#!/bin/sh
# Vergleichsmessung Kernel (Ergebnis nach /root/messung-<kernel>.txt)
k=$(uname -r); o=/root/messung-$k.txt
{
echo "Kernel: $k  $(date '+%d.%m.%Y %H:%M')"
systemd-analyze | head -1
echo "RAM benutzt (MB): $(free -m | awk '/Speicher|Mem/{print $3}')"
echo "Module geladen: $(lsmod | tail -n +2 | wc -l)"
echo "-- cyclictest 30 s (Latenz in us, min/avg/max je Kern)"
cyclictest -q -m -S -p 80 -i 1000 -D 30 2>/dev/null | awk '/Max/{print "  T"$2" Min "$10" Avg "$14" Max "$16}' 
echo "-- hackbench (Sekunden, kleiner = besser)"
for i in 1 2 3; do hackbench -g 4 -l 500 2>/dev/null | awk '/Time/{print "  "$2}'; done
echo "-- sysbench cpu 4 Threads (Ereignisse/s)"
sysbench cpu --threads=4 --time=15 run 2>/dev/null | awk '/events per second/{print "  "$4}'
echo "-- sysbench memory (MiB/s)"
sysbench memory --threads=4 --memory-total-size=4G run 2>/dev/null | awk '/MiB\/sec/{print "  "$(NF-1)" "$NF}'
} > $o 2>&1
cat $o
