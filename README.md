# suman-algrgb

Native Linux ACPI lighting driver, CLI, and Omarchy shell plugin for the **Acer Aspire Lite AL15G-52**.

---

## Supported Hardware

| Model | Compatibility | ACPI Device | Interface |
|---|:---:|---|---|
| **Acer Aspire Lite AL15G-52** | Native | `CLV0001:00` | `\_SB.DCHU` (`_DSM 0x67`) |
| **Acer Aspire Lite (CLV0001 Series)** | Compatible | `CLV0001:00` | `\_SB.DCHU` (`_DSM 0x67`) |

Verify your hardware:
```bash
cat /sys/class/dmi/id/product_name    # Expected: Aspire Lite AL15G-52
ls -d /sys/bus/acpi/devices/CLV0001:00
```

---

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│                      USER INTERFACES                      │
│    Unix CLI (alg-rgb)    ·    Omarchy Shell Plugin        │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                    LINUX KERNEL DRIVER                    │
│    /dev/alg_rgb   ·   DKMS alg_rgb.ko   ·  GRB Conversion │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                    ACPI FIRMWARE LAYER                    │
│    CLV0001:00     ·    _DSM 0x67        ·  UUID 93f224e4  │
└─────────────────────────┬─────────────────────────────────┘
                          ▼
┌───────────────────────────────────────────────────────────┐
│                  EMBEDDED CONTROLLER                      │
│    [0xF0] Main typing zone   ·   [0xF3] Light Bar         │
└───────────────────────────────────────────────────────────┘
```

---

## Installation

### Prerequisites

```bash
# Arch Linux
sudo pacman -S linux-headers dkms base-devel

# Fedora / RHEL
sudo dnf install kernel-devel-$(uname -r) dkms gcc make

# Ubuntu / Debian
sudo apt install linux-headers-$(uname -r) dkms build-essential
```

### Quick Install

```bash
git clone git@github.com:sumanezhumalai/omarhcy-algrgb.git
cd omarhcy-algrgb
sudo bash ./install.sh
```

The installer:
1. Builds and installs `/usr/local/bin/alg-rgb`.
2. Registers and builds the `alg_rgb` DKMS kernel module.
3. Installs udev rules for unprivileged seat access (`/dev/alg_rgb`).
4. Configures systemd state restore and sleep/resume hooks.
5. Automatically installs the Omarchy shell plugin if Omarchy is present.

### User Permissions

```bash
sudo usermod -aG alg-rgb "$USER"
newgrp alg-rgb
```

---

## CLI Usage

```bash
# Preset and hex colors
alg-rgb red
alg-rgb cyan 4
alg-rgb '#98d7c2' 2

# Brightness control (0 to 4)
alg-rgb brightness 3
alg-rgb off        # Backlight off
alg-rgb on         # Restore previous brightness

# Motion effects
alg-rgb effect wave     # Traveling wave
alg-rgb effect cycle    # Rainbow spectrum loop
alg-rgb effect breath   # Breathing fade
alg-rgb effect tempo    # Beat pulse
alg-rgb effect dance    # Alternate zone pattern
alg-rgb effect random   # Random per-zone pattern
alg-rgb effect static   # Solid static color

# Status & diagnostics
alg-rgb status
alg-rgb status --json
alg-rgb probe
```

---

## Omarchy Shell Plugin

A native status bar widget and control panel (`suman.alg-rgb`) is included under `plugin/suman.alg-rgb`.

- **Bar Widget**: Clean white Font Awesome keyboard icon (``) matching Omarchy native aesthetics. Dims automatically when the backlight is off or standby.
- **Control Panel**:
  - Live color preview swatch and power toggle.
  - Discrete brightness slider (levels 1 to 4).
  - **Dynamic Theme Matching**: Automatically pairs the keyboard backlight with the active Omarchy theme's accent color live whenever themes switch.
  - **Curated Warm Presets**: One-click static lock into warm, eye-easy aesthetic tones (Flesh `#ff7f3f`, Warm Orange `#ff7f00`, Amber Sand `#e0af68`, Buttercream `#ded885`).
- **Interactions**:
  - **Left-Click**: Toggle the control panel popup.
  - **Right-Click**: Toggle backlight power on/off.

---

## Hardware Safety & Protocol

### ACPI `_DSM` Function 0x67
- **UUID**: `93f224e4-fbdc-4bbf-add6-db71bdc0afad`
- **Function**: `0x67`
- **Payload**: 4-byte buffer `[Green, Red, Blue, Zone/Command]` (GRB byte order converted automatically by the driver).

> [!CAUTION]
> Functions `0x68`, `0x69`, `0x6A` are strictly quarantined — these cause embedded controller lockups on related hardware during reverse engineering. `alg-rgb probe` is strictly read-only.

---

## Troubleshooting

### `/dev/alg_rgb` Missing
```bash
sudo dkms status
sudo modprobe alg_rgb
dmesg | grep alg_rgb
```

### Permission Denied
```bash
sudo usermod -aG alg-rgb "$USER"
newgrp alg-rgb
```

---

## License & Credits

- **License**: GNU General Public License v2.0 ([GPL-2.0](LICENSE))
- **Based on research by**: Kaushik ([`24kaushik/alg-cli`](https://github.com/24kaushik/alg-cli)) and Chirag Koyande for initial ACPI CLV0001 discovery.
