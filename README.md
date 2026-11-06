# surface3-linux

Microsoft Surface 3 (Atom x7-Z8700, Cherry Trail, 4 GB) on Debian testing with KDE Plasma 6 (Wayland): patches, settings and findings.

## What works

| Area | Status | How |
|---|---|---|
| Touchscreen and pen | works | linux-surface patches (`surface3_spi`) |
| Wi-Fi | stable | power saving off, suspend off |
| Sound | works | `firmware-intel-sound`, speaker as default sink |
| Battery and AC adapter | works | kernel patch for `surface3_power` |
| On-screen keyboard | works | `plasma-keyboard` (Plasma 6.7), hidden while the Type Cover is attached |
| Automatic rotation | works | accelerometer hysteresis set to 0 |
| Hardware video in Chromium | works, 1080p60 is smooth | patched i965 VA-API driver + H.264 on YouTube |
| Suspend | disabled on purpose | the Marvell Wi-Fi chip does not wake up reliably |

## Findings

### 1. AC adapter no longer detected after an error (`surface3_power`)
- **Symptom:** after unplugging and replugging the charger, the AC icon does not change, `/sys/class/power_supply/ADP1/online` returns `ENODEV`, and the log shows `i2c_designware 808622C1:00: controller timed out` followed by `Unknown exception code 0xFFFFFF92`.
- **Causes in the driver:**
  - The `mshw0011_adp` polling thread exits on the first I²C error and is never restarted, so AC adapter changes are no longer reported.
  - The ACPI operation region handler and the polling thread access the controller without a common lock. The BST and BIX commands consist of several SMBus transfers, which can interleave.
  - Negative errno values are passed to ACPICA as `acpi_status`.
- **Patch:** [`patches/kernel/0001-platform-surface-surface3_power-serialize-I2C-access.patch`](patches/kernel/) (against v7.3, also applies to 6.18). It serializes every command sequence with a mutex, keeps polling after errors and returns `AE_ERROR`.
- No fixed regression between 6.18 and 7.3 could be shown: vanilla 7.3 and the patched 7.3 each survived several charger changes and load tests with up to 16 parallel readers. The failure is a rare race.

### 2. Sporadic I²C and SPI bus hangs (open, under observation)
- The battery I²C bus (`808622C1:00`) and the touchscreen SPI bus (`8086228E:00`) both belong to the chip's LPSS block. Each hung once during YouTube use with touch input; a reboot fixes it.
- Full load alone (4 CPU threads, video playback, battery readers) does not trigger it.
- **Experiment:** runtime PM is disabled for these controllers and the LPSS DMA ([`80-lpss-kein-runtime-pm.rules`](system/etc/udev/rules.d/)). A watcher ([`lpss-waechter`](system/usr/local/bin/)) writes a snapshot of the system state to `/root/lpss-vorfall.log` on the first error per bus.

### 3. No automatic rotation
- With the default accelerometer hysteresis of `0.1`, the HID sensor hub (`MSHW0102`, HID over I²C) reports nothing. sysfs shows a constant `0,0,-1000`, and `iio-sensor-proxy` logs "Buffer did not have data within 0.5s".
- **Fix:** set `in_accel_hysteresis=0` via udev ([`70-surface3-sensoren.rules`](system/etc/udev/rules.d/)). Plasma then rotates automatically in tablet mode (Type Cover detached).

### 4. Chromium decodes video in software only
- The i965 driver allocates the memory of a surface lazily, on the first decode. Chromium exports the surface with `vaExportSurfaceHandle()` before that, gets `invalid VASurfaceID` and silently falls back to the CPU.
- **Patch:** [`patches/i965/0001-allocate-bo-on-export.patch`](patches/i965/) allocates the buffer on export. Build and install it with `./einrichten.sh --i965`.
- Cherry Trail decodes H.264, HEVC (8 bit), VP8, MPEG-2 and VC-1, but not VP9 or AV1. The [enhanced-h264ify](https://github.com/alextrv/enhanced-h264ify) extension is installed by policy and makes YouTube serve H.264.
- Result: YouTube 1080p30 needs about 25 % CPU in the renderer instead of about 245 %.

### 5. Other pitfalls
- **Black screen after login:** ACPI reports the lid as closed and KWin turns the display off. Fix: `button.lid_init_state=open` and lid action "do nothing".
- **On-screen keyboard while the Type Cover is attached:** [`osk-typecover`](system/usr/local/bin/) sets KWin's virtual keyboard mode when the cover is attached or detached (udev) and at login.
- **Maliit on Plasma 6.3** needed `qtwayland5`; on Debian testing, `plasma-keyboard` is far better.
- **Kernel parameters:** `intel_idle.max_cstate=1 i915.enable_psr=0 button.lid_init_state=open`.

## Measurements (kernels compared)

| Kernel | Max latency | hackbench | sysbench CPU | Memory | Kernel boot |
|---|---|---|---|---|---|
| Debian 6.12 | 1622 µs | 3.16 s | 2090 | 4600 MiB/s | 3.7 s |
| 6.18 custom build | 171 µs | 3.22 s | 2038 | 4176 MiB/s | 3.3 s |
| 7.3 custom build | 143 µs | 3.14 s | 2053 | 4449 MiB/s | 3.2 s |

Custom builds: linux-surface patches, `PREEMPT`, `HZ_1000`, `-march=silvermont`. Raw data in [`messungen/`](messungen/), measurement script [`skripte/messen.sh`](skripte/messen.sh).

## Contents

| Path | Contents |
|---|---|
| `einrichten.sh` | applies everything (packages, system files, kernel parameters, user settings); `--i965` also builds the patched driver |
| `patches/` | kernel patch (`surface3_power`) and i965 patch |
| `system/` | files in their target layout (`/etc`, `/usr`) |
| `kernel/` | build scripts for the custom kernel (7.3.1 and 6.18.60 with linux-surface) and for bisecting |
| `skripte/` | load tests (`i2ctest.sh`, `lasttest.sh`), benchmark, upgrade to Debian testing, base Plasma install |
| `messungen/` | benchmark results |

Script names and comments are in German.

## Setup

```sh
git clone https://github.com/rony-x2/surface3-linux.git
cd surface3-linux
sudo ./einrichten.sh --i965
sudo reboot
```

The custom kernel is built separately with the scripts in `kernel/`. They expect a working directory `~/kernelbau` containing the kernel source and the [linux-surface](https://github.com/linux-surface/linux-surface) repository. The Debian packages are built on a faster machine and installed on the Surface with `dpkg -i`.

## License

Scripts and configuration: MIT (see [`LICENSE`](LICENSE)). The kernel patch is GPL-2.0 like the kernel, the i965 patch MIT like the driver.

Dennis Deutschkämer, <dennis@deutschkaemer.info>
