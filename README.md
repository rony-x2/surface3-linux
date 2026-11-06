# surface3-linux

Microsoft Surface 3 (Atom x7-Z8700, Cherry Trail, 4 GB) unter Debian testing mit KDE Plasma 6 (Wayland): Patches, Einstellungen und Erkenntnisse.

*English version below.*

## Was funktioniert

| Bereich | Stand | Wie |
|---|---|---|
| Touchscreen und Stift | läuft | linux-surface-Patches (`surface3_spi`) |
| WLAN | stabil | Energiesparen aus, Standby aus |
| Ton | läuft | `firmware-intel-sound`, Lautsprecher als Standard |
| Akku und Netzteil | läuft | Kernel-Patch `surface3_power` |
| Bildschirmtastatur | läuft | `plasma-keyboard` (Plasma 6.7), schaltet sich mit Type Cover ab |
| Automatische Drehung | läuft | Hysterese des Lagesensors auf 0 |
| Hardware-Video in Chromium | läuft, 1080p60 flüssig | gepatchter i965-VA-API-Treiber + H.264 auf YouTube |
| Standby | bewusst aus | WLAN-Chip wacht nicht zuverlässig auf |

## Erkenntnisse

### 1. Netzteil wird nach einem Fehler nicht mehr erkannt (`surface3_power`)
- **Symptom:** Nach dem Ab- und Anstecken bleibt das Netzteil-Symbol stehen, `/sys/class/power_supply/ADP1/online` liefert `ENODEV`, im Log `i2c_designware 808622C1:00: controller timed out` und `Unknown exception code 0xFFFFFF92`.
- **Ursachen im Treiber:**
  - Der Poll-Thread `mshw0011_adp` beendet sich beim ersten I²C-Fehler für immer.
  - ACPI-Opregion-Handler und Poll-Thread greifen ohne gemeinsame Sperre auf den Controller zu; BST und BIX bestehen aus mehreren SMBus-Transfers, die sich überlappen können.
  - Negative errno-Werte werden als `acpi_status` an ACPICA gereicht.
- **Patch:** [`patches/kernel/0001-platform-surface-surface3_power-serialize-I2C-access.patch`](patches/kernel/) (gegen v7.3, passt auch auf 6.18).
- Eine feste Regression zwischen 6.18 und 7.3 ließ sich nicht nachweisen: Reines 7.3 und gepatchtes 7.3 überstanden je mehrere Netzteil-Wechsel und Lasttests mit bis zu 16 parallelen Lesern. Der Fehler ist ein seltener Wettlauf.

### 2. I²C- und SPI-Bus hängen sporadisch (offen, unter Beobachtung)
- Akku-I²C (`808622C1:00`) und Touchscreen-SPI (`8086228E:00`) gehören beide zum LPSS-Block des Chips. Beide hingen einmal während YouTube-Nutzung mit Touch-Bedienung; ein Neustart behebt es.
- Volllast allein (4 CPU-Threads, Video, Akku-Leser) löst es nicht aus.
- **Versuch:** Runtime-PM für diese Bausteine und die LPSS-DMA abschalten ([`80-lpss-kein-runtime-pm.rules`](system/etc/udev/rules.d/)). Ein Wächter ([`lpss-waechter`](system/usr/local/bin/)) schreibt beim ersten Fehler ein Lastbild nach `/root/lpss-vorfall.log`.

### 3. Keine automatische Drehung
- Der Sensor-Hub (`MSHW0102`, HID über I²C) liefert mit der voreingestellten Hysterese `0.1` keine Werte, sysfs zeigt dauerhaft `0,0,-1000`; `iio-sensor-proxy` meldet „Buffer did not have data“.
- **Lösung:** `in_accel_hysteresis=0` per udev ([`70-surface3-sensoren.rules`](system/etc/udev/rules.d/)). Plasma dreht dann im Tablet-Modus (ohne Type Cover).

### 4. Chromium dekodiert Video nur in Software
- Der i965-Treiber legt den Speicher einer Surface erst beim ersten Dekodieren an. Chromium exportiert sie vorher mit `vaExportSurfaceHandle()` und bekommt `invalid VASurfaceID`, fällt dann still auf die CPU zurück.
- **Patch:** [`patches/i965/0001-allocate-bo-on-export.patch`](patches/i965/), Bau über `./einrichten.sh --i965`.
- Cherry Trail dekodiert H.264, HEVC (8 Bit), VP8, MPEG-2 und VC-1, aber kein VP9/AV1. Die Erweiterung [enhanced-h264ify](https://github.com/alextrv/enhanced-h264ify) wird per Richtlinie installiert und lässt YouTube H.264 liefern.
- Ergebnis: YouTube 1080p30 mit ~25 % CPU im Renderer statt ~245 %.

### 5. Weitere Stolpersteine
- **Schwarzer Bildschirm nach der Anmeldung:** ACPI meldet den Deckel als geschlossen, KWin schaltet das Display ab. Abhilfe: `button.lid_init_state=open`, Deckel-Aktion „nichts tun“.
- **Bildschirmtastatur bei angestecktem Type Cover:** [`osk-typecover`](system/usr/local/bin/) setzt den KWin-Modus der Bildschirmtastatur beim An- und Abstecken (udev) und bei der Anmeldung.
- **Maliit unter Plasma 6.3** brauchte `qtwayland5`; mit Debian testing ist `plasma-keyboard` deutlich besser.
- **Kernel-Parameter:** `intel_idle.max_cstate=1 i915.enable_psr=0 button.lid_init_state=open`.

## Messungen (Kernel im Vergleich)

| Kernel | Latenz max. | hackbench | sysbench CPU | Speicher | Kernel-Start |
|---|---|---|---|---|---|
| Debian 6.12 | 1622 µs | 3,16 s | 2090 | 4600 MiB/s | 3,7 s |
| 6.18 eigener Bau | 171 µs | 3,22 s | 2038 | 4176 MiB/s | 3,3 s |
| 7.3 eigener Bau | 143 µs | 3,14 s | 2053 | 4449 MiB/s | 3,2 s |

Eigene Bauten: linux-surface-Patches, `PREEMPT`, `HZ_1000`, `-march=silvermont`. Rohdaten in [`messungen/`](messungen/), Messskript [`skripte/messen.sh`](skripte/messen.sh).

## Inhalt

| Ordner | Inhalt |
|---|---|
| `einrichten.sh` | wendet alles an (Pakete, Systemdateien, Kernel-Parameter, Benutzereinstellungen), mit `--i965` auch den Treiber-Patch |
| `patches/` | Kernel-Patch (`surface3_power`) und i965-Patch |
| `system/` | Dateien in ihrer Zielstruktur (`/etc`, `/usr`) |
| `kernel/` | Bauskripte für den eigenen Kernel (7.3.1 und 6.18.60 mit linux-surface) und für Bisektionen |
| `skripte/` | Lasttests (`i2ctest.sh`, `lasttest.sh`), Messung, Umstieg auf Debian testing, Plasma-Grundinstallation |
| `messungen/` | Messergebnisse |

## Einrichtung

```sh
git clone https://github.com/rony-x2/surface3-linux.git
cd surface3-linux
sudo ./einrichten.sh --i965
sudo reboot
```

Den eigenen Kernel baut man getrennt mit den Skripten in `kernel/`; sie erwarten einen Arbeitsordner `~/kernelbau` mit dem Kernel-Quelltext und dem [linux-surface](https://github.com/linux-surface/linux-surface)-Repo. Die Debian-Pakete werden auf einem schnelleren Rechner gebaut und auf dem Surface mit `dpkg -i` installiert.

---

## English

Microsoft Surface 3 (Atom x7-Z8700, Cherry Trail, 4 GB) on Debian testing with KDE Plasma 6 (Wayland): patches, settings and findings.

**What works:** touchscreen and pen (linux-surface), stable Wi-Fi (power saving and suspend off), sound, battery and AC adapter, the `plasma-keyboard` on-screen keyboard (hidden while the Type Cover is attached), automatic screen rotation, and hardware video decoding in Chromium (YouTube 1080p60 runs smoothly).

**Findings:**
1. **`surface3_power`:** the `mshw0011_adp` polling thread exits on the first I²C error, so AC adapter changes are no longer reported. The operation region handler and the thread access the controller without a common lock, and negative errno values are passed to ACPICA as `acpi_status`. The [kernel patch](patches/kernel/) serializes all command sequences, keeps polling after errors and returns `AE_ERROR`. No fixed regression between 6.18 and 7.3 could be shown; the failure is a rare race.
2. **Sporadic I²C/SPI bus hangs (open):** the battery I²C bus and the touchscreen SPI bus (both in the LPSS block) each hung once during YouTube use with touch input. Runtime PM for them and the LPSS DMA is now disabled as an experiment, and a watcher logs the system state on the first error.
3. **No auto rotation:** the HID sensor hub (`MSHW0102`) reports nothing with the default accelerometer hysteresis of `0.1`. Setting `in_accel_hysteresis=0` via udev fixes it.
4. **No hardware video in Chromium:** i965 allocates surface memory lazily, so Chromium's early `vaExportSurfaceHandle()` fails with `invalid VASurfaceID`. The [i965 patch](patches/i965/) allocates the buffer on export. Cherry Trail has no VP9/AV1 decoder, so [enhanced-h264ify](https://github.com/alextrv/enhanced-h264ify) makes YouTube serve H.264.
5. **Other:** black screen after login (ACPI reports the lid as closed: `button.lid_init_state=open`), kernel parameters `intel_idle.max_cstate=1 i915.enable_psr=0 button.lid_init_state=open`.

**Setup:** `sudo ./einrichten.sh --i965`, then reboot. Script names and comments are in German.

## Lizenz / License

Skripte und Konfiguration: MIT (siehe [`LICENSE`](LICENSE)). Der Kernel-Patch steht wie der Kernel unter GPL-2.0, der i965-Patch wie der Treiber unter MIT.

Scripts and configuration: MIT. The kernel patch is GPL-2.0 like the kernel, the i965 patch MIT like the driver.

Dennis Deutschkämer, <dennis@deutschkaemer.info>
